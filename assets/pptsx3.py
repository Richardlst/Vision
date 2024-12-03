import pyttsx3

# Khởi tạo engine
engine = pyttsx3.init()

# Lấy danh sách giọng nói
voices = engine.getProperty('voices')

# Hiển thị thông tin các giọng nói
for voice in voices:
    print(f"ID: {voice.id}")
    print(f"Name: {voice.name}")
    print(f"Languages: {voice.languages}")
    print("-----------")
