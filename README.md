<div align="center" style="display: flex; flex-direction: row; align-items: center; justify-content: center; gap: 10px;">  
    <img alt="Logo" src="presentation/Logo.svg" width="150" height="150"/>  
</div>  

<div align="center">  
    <h1>GigaSecretary</h1>  


![Contributors](https://img.shields.io/github/contributors/GigaGitCoder/GigaSecretary)
![Issues](https://img.shields.io/github/issues/GigaGitCoder/GigaSecretary)
![MIT License](https://img.shields.io/github/license/GigaGitCoder/GigaSecretary)
![Forks](https://img.shields.io/github/forks/GigaGitCoder/GigaSecretary)
![Stars](https://img.shields.io/github/stars/GigaGitCoder/GigaSecretary)  

</div>  

> 🏆 Этот проект был разработан в рамках хакатона **Хакатон Весна 2025** (4–6 апреля 2025) <br>
> <img src="https://img.icons8.com/fluency/48/000000/microsoft-powerpoint-2019.png" width="20" height="20"/> **[Презентация проекта](GigaSecretary.pptx)**  

> Хакатон Весна 2025 — это масштабное мероприятие для IT-энтузиастов, проходившее в Манеже ДГТУ (Ростов-на-Дону), в рамках Южного ИТ-форума. Организаторы: ЮФУ, РГЭУ (РИНХ), РГУПС, ДГТУ и Сбербанк.

## 🛠 Стек технологий  

- <img src="https://upload.wikimedia.org/wikipedia/commons/c/c3/Python-logo-notext.svg" width="13" height="13"/> Python 3.8+  
- <img src="https://huggingface.co/front/assets/huggingface_logo.svg" width="13" height="13"/> HuggingFace Transformers  
- <img src="https://img.icons8.com/color/48/000000/dart.png" width="13" height="13"/> Dart  
- <img src="https://img.icons8.com/color/48/000000/flutter.png" width="13" height="13"/> Flutter  
- <img src="https://img.icons8.com/color/48/000000/google-logo.png" width="13" height="13"/> Google API  
- <img src="https://img.icons8.com/color/48/000000/figma--v1.png" width="13" height="13"/> Figma  

## 🚀 Установка и запуск

1. Клонируйте репозиторий:
```bash
git clone https://github.com/GigaGitCoder/GigaSecretary.git
cd GigaSecretary
```

2. Установите зависимости:
```bash
pip install -r requirements.txt
```

3. Получите Hugging Face Token:
- Зарегистрируйтесь на [huggingface.co](https://huggingface.co)
- Скопируйте ваш **Access Token**
- Создайте файл `.env` в корне проекта со следующим содержанием:
```env
HF_TOKEN=ваш_токен_от_huggingface
```

4. Перейдите по ссылкам и запросите доступ к моделям:
- [pyannote/segmentation-3.0](https://huggingface.co/pyannote/segmentation-3.0)
- [pyannote/speaker-diarization-3.1](https://huggingface.co/pyannote/speaker-diarization-3.1)

5. Настройте доступ к Google API: 
- **Создайте новый проект в [Google Cloud Console](https://console.cloud.google.com/)**.  
- **Включите Google Drive API**.  
- **Настройте OAuth 2.0 Client ID**:  
   - Укажите **имя пакета** (например, `com.example.myapp`).  
   - Получите **SHA-1 отпечаток** с помощью следующей команды:  
     ```bash  
     keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore  
     ```  
- **Скачайте `credentials.json`** и поместите его в директорию `android/app`.  

6. Найдите IP-адрес вашего ПК (если нет белого IP) и укажите его:
- В файле `api.py`, последние строки:
```python
if __name__ == "__main__":
    uvicorn.run(app, host="ВАШ_IP", port=10000, log_level="info")
```

- В файле `conversation_service.dart`, строка 218:
```dart
const apiUrl = 'http://ВАШ_IP:Port/process_audio/';
```

## 📝 Использование

### Задача проекта:

1. Запись аудиобеседы нескольких участников и/или загрузка записи встречи.
2. Распознавание речи с выделением спикеров.
3. Присвоение имён спикерам через интерфейс.
4. Генерация краткого пересказа беседы.
5. Автоматическое выделение обязательств: кто, что и до какого срока должен сделать.
6. Отображение результатов в интерфейсе:
   - Полная транскрипция
   - Краткий пересказ
   - Обязательства
   - Даты

## 🔮 Возможное развитие

1. Размещение сервиса на сервере (облачная/локальная инфраструктура)
2. Расширение функциональности: закончить поставленные на хакатоне задачи
3. Благодаря использованию Flutter — реализация полной кроссплатформенности (iOS, Web)

## 👥 Команда разработчиков
<table>
  <tr>
    <th colspan="4" style="text-align:center; font-size: 18px; padding: 10px; background-color: #f0f0f0; border: 1px solid #555;">Backend</th>
  </tr>
  <tr>
    <td align="center" style="border: 1px solid #555;">
      <img src="https://github.com/GigaGitCoder.png" width="100" height="100" style="border-radius: 50%" alt="avatar"><br />
      <b>Егор Холкин</b><br />
      <sub><i>Тимлид, Full-stack разработчик</i></sub>
      <hr style="border: 1px solid #555; margin: 10px 0;">
      <div align="left">
        <b>Вклад в проект:</b><br />
        • Backend разработка<br />
        • Создание API<br />
        • Руководство проектом
        <hr style="border: 1px solid #555; margin: 10px 0;">
        <b>Контакты:</b><br />
        <a href="https://github.com/GigaGitCoder">GitHub</a> • <a href="https://t.me/IgorXmel">Telegram</a>
      </div>
    </td>
    <td align="center" style="border: 1px solid #555;">
      <img src="https://github.com/Anton2442.png" width="100" height="100" style="border-radius: 50%" alt="avatar"><br />
      <b>Антон Михайличенко</b><br />
      <sub><i>Backend разработчик</i></sub>
      <hr style="border: 1px solid #555; margin: 10px 0;">
      <div align="left">
        <b>Вклад в проект:</b><br />
        • Backend разработка<br />
        • Доработка API<br />
        • Создание мобильного приложения
        <hr style="border: 1px solid #555; margin: 10px 0;">
        <b>Контакты:</b><br />
        <a href="https://github.com/Anton2442">GitHub</a> • <a href="https://t.me/Kish242">Telegram</a>
      </div>
    </td>
    <td align="center" style="border: 1px solid #555;">
      <img src="https://github.com/Malanhei.png" width="100" height="100" style="border-radius: 50%" alt="avatar"><br />
      <b>Цызов Владимир</b><br />
      <sub><i>Backend разработчик</i></sub>
      <hr style="border: 1px solid #555; margin: 10px 0;">
      <div align="left">
        <b>Вклад в проект:</b><br />
        • Backend разработка<br />
        • Создание API
        <hr style="border: 1px solid #555; margin: 10px 0;">
        <b>Контакты:</b><br />
        <a href="https://github.com/Malanhei">GitHub</a> • <a href="https://t.me/malanhei">Telegram</a>
      </div>
    </td>
  </tr>
  <tr>
    <th colspan="4" style="text-align:center; font-size: 18px; padding: 10px; background-color: #f0f0f0; border: 1px solid #555;">Frontend</th>
  </tr>
  <tr>
    <td align="center" style="border: 1px solid #555;">
      <img src="https://github.com/Xqyat.png" width="100" height="100" style="border-radius: 50%" alt="avatar"><br />
      <b>Роман Колесников</b><br />
      <sub><i>Frontend разработчик</i></sub>
      <hr style="border: 1px solid #555; margin: 10px 0;">
      <div align="left">
        <b>Вклад в проект:</b><br />
        • Frontend разработка<br />
        • Руководство над дизайном проекта<br />
        • Создание презентации
        <hr style="border: 1px solid #555; margin: 10px 0;">
        <b>Контакты:</b><br />
        <a href="https://github.com/Xqyat">GitHub</a> • <a href="https://t.me/Forliot">Telegram</a>
      </div>
    </td>
    <td align="center" style="border: 1px solid #555;">
      <img src="https://github.com/dencraz.png" width="100" height="100" style="border-radius: 50%" alt="avatar"><br />
      <b>Даниил Сапронов</b><br />
      <sub><i>Frontend разработчик</i></sub>
      <hr style="border: 1px solid #555; margin: 10px 0;">
      <div align="left">
        <b>Вклад в проект:</b><br />
        • Frontend разработка<br />
        • UX/UI дизайн<br />
        • Создание презентации
        <hr style="border: 1px solid #555; margin: 10px 0;">
        <b>Контакты:</b><br />
        <a href="https://github.com/dencraz">GitHub</a> • <a href="https://t.me/dencraz">Telegram</a>
      </div>
    </td>
    <td align="center" style="border: 1px solid #555;">
      <img src="https://github.com/DynamitNS.png" width="100" height="100" style="border-radius: 50%" alt="avatar"><br />
      <b>Сергей Товмасян</b><br />
      <sub><i>Frontend разработчик</i></sub>
      <hr style="border: 1px solid #555; margin: 10px 0;">
      <div align="left">
        <b>Вклад в проект:</b><br />
        • Frontend разработка<br />
        • UX/UI дизайн<br />
        • Создание презентации
        <hr style="border: 1px solid #555; margin: 10px 0;">
        <b>Контакты:</b><br />
        <a href="https://github.com/DynamitNS">GitHub</a> • <a href="https://t.me/DynamitNS">Telegram</a>
      </div>
    </td>
  </tr>
</table>

## 📄 Лицензия

Проект распространяется под лицензией MIT. Подробности в [LICENSE](LICENSE).
