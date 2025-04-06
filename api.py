import os
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
import whisper
import torch
from pyannote.audio import Pipeline
from pydub import AudioSegment
import tempfile
import logging
import re
from typing import Dict, List
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()

# Конфигурация логгера
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        cuda_available = torch.cuda.is_available()
        device = torch.device("cuda" if cuda_available else "cpu")
        logger.info(f"CUDA available: {cuda_available}")
        if cuda_available:
            logger.info(f"Using GPU: {torch.cuda.get_device_name(0)}")
        else:
            logger.warning("CUDA not available. Using CPU.")

        whisper_model = whisper.load_model("small", device=device)
        logger.info(f"Whisper loaded on {device}")

        diarization_pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=os.getenv("HF_TOKEN") # Ваш токен
        )
        diarization_pipeline.to(device)
        logger.info(f"Diarization pipeline moved to {device}")

        app.state.whisper_model = whisper_model
        app.state.diarization_pipeline = diarization_pipeline

        yield

    except Exception as e:
        logger.error(f"Model loading failed: {str(e)}")
        raise
    finally:
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

app = FastAPI(lifespan=lifespan)

def convert_to_wav(input_path: str, output_path: str) -> bool:
    try:
        # Проверяем существование файла
        if not os.path.exists(input_path):
            logger.error(f"Файл не найден: {input_path}")
            return False
            
        # Проверяем размер файла
        file_size = os.path.getsize(input_path)
        logger.info(f"Размер файла: {file_size} байт")
        if file_size == 0:
            logger.error("Пустой файл")
            return False
            
        # Проверяем формат файла
        file_ext = os.path.splitext(input_path)[1].lower()
        logger.info(f"Формат файла: {file_ext}")
        if file_ext not in ['.mp3', '.wav', '.ogg', '.m4a']:
            logger.error(f"Неподдерживаемый формат файла: {file_ext}")
            return False
            
        # Загружаем аудио
        logger.info("Загрузка аудио...")
        audio = AudioSegment.from_file(input_path)
        if len(audio) == 0:
            logger.error("Не удалось загрузить аудио")
            return False
            
        # Конвертируем в нужный формат
        logger.info("Конвертация в WAV...")
        audio = audio.set_frame_rate(16000).set_channels(1)
        audio.export(output_path, format="wav")
        logger.info("Конвертация успешно завершена")
        return True
    except Exception as e:
        logger.error(f"Ошибка конвертации аудио: {str(e)}")
        return False

def extract_events(speakers: List[Dict]) -> List[Dict]:
    events = []
    seen_dates = set()
    date_patterns = [
        r"\b(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\b",
        r"\b(\d{1,2}\s+(?:января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)(?:\s+\d{4})?)\b",
        r"\b(вчера|сегодня|завтра)\b"
    ]

    for speaker in speakers:
        text = speaker["text"]
        for pattern in date_patterns:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                date = match.group(0).strip()
                if date.lower() not in seen_dates:
                    seen_dates.add(date.lower())
                    events.append({
                        "date": date,
                        "event": text.strip(),
                        "speaker": speaker["speaker"]
                    })
    return events

def extract_duties(speakers: List[Dict]) -> List[Dict]:
    duties = []
    seen = set()

    duty_triggers = [
        r"(должен|обязан|нужно|необходимо|следует|поручается|надо|придётся|возьмись|ответственность|твоя задача|назначен)",
        r"(сделай|выполни|реализуй|напиши|подготовь|организуй|запусти|разработай|оптимизируй|исправь|установи|проверь|опубликуй)"
    ]

    for speaker in speakers:
        text = speaker["text"]
        for trigger in duty_triggers:
            matches = re.finditer(rf"[^.!?]*?\b{trigger}\b[^.!?]*[.!?]", text, re.IGNORECASE)
            for match in matches:
                duty_text = match.group(0).strip()
                if duty_text.lower() not in seen and len(duty_text) > 10:
                    seen.add(duty_text.lower())
                    duties.append({
                        "duty": duty_text,
                        "speaker": speaker["speaker"]
                    })
    return duties

def process_audio_segments(file_path: str) -> Dict:
    try:
        diarization = app.state.diarization_pipeline(file_path)
        segments = list(diarization.itertracks(yield_label=True))

        if not segments:
            return {"speakers": [], "events": [], "duties": []}

        audio = AudioSegment.from_wav(file_path)
        grouped_speakers = []
        current_speaker = None
        current_start = None
        current_text = []

        for turn, _, speaker in segments:
            start = turn.start
            end = turn.end
            if end <= start or (end - start) < 0.2:
                continue

            segment = audio[int(start * 1000):int(end * 1000)]
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as seg_file:
                segment.export(seg_file.name, format="wav")
                seg_file.close()
                try:
                    result = app.state.whisper_model.transcribe(
                        seg_file.name,
                        language="ru",
                        temperature=0.2
                    )
                finally:
                    os.unlink(seg_file.name)

            text = result["text"].strip()
            if not text:
                continue

            if current_speaker != speaker and current_speaker is not None:
                grouped_speakers.append({
                    "speaker": current_speaker,
                    "start": current_start,
                    "end": turn.start,
                    "duration": turn.start - current_start,
                    "text": " ".join(current_text)
                })
                current_text = []

            if current_speaker != speaker:
                current_speaker = speaker
                current_start = start

            current_text.append(text)

        if current_speaker and current_text:
            grouped_speakers.append({
                "speaker": current_speaker,
                "start": current_start,
                "end": segments[-1][0].end,
                "duration": segments[-1][0].end - current_start,
                "text": " ".join(current_text)
            })

        events = extract_events(grouped_speakers)
        duties = extract_duties(grouped_speakers)

        return {
            "speakers": grouped_speakers,
            "events": events,
            "duties": duties
        }

    except Exception as e:
        logger.error(f"Audio processing failed: {str(e)}")
        torch.cuda.empty_cache()
        raise HTTPException(500, detail="Ошибка при обработке аудио: " + str(e))

@app.post("/process_audio/")
async def process_audio(file: UploadFile = File(...)):
    with tempfile.TemporaryDirectory() as temp_dir:
        input_path = os.path.join(temp_dir, file.filename or "input_audio")
        wav_path = os.path.join(temp_dir, "audio.wav")

        with open(input_path, "wb") as f:
            f.write(await file.read())

        if not convert_to_wav(input_path, wav_path):
            raise HTTPException(400, "Неподдерживаемый формат аудио или пустой файл")

        return JSONResponse(content=process_audio_segments(wav_path))

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "whisper": str(app.state.whisper_model.device),
        "diarization": "loaded" if hasattr(app.state, 'diarization_pipeline') else "error"
    }

if __name__ == "__main__":
    uvicorn.run(app, host="your ip", port=10000, log_level="info") # Сюда вставляем ip сервера
