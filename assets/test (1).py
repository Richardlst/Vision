import os
from gtts import gTTS
from playsound import playsound

# Tạo file âm thanh
text = "thật là dễ hiểu mà"
output_file = "output.mp3"
tts = gTTS(text=text, lang='vi')
tts.save(output_file)

# Phát file âm thanh
playsound(output_file)

# Xóa file âm thanh sau khi phát
os.remove(output_file)

# pip install gTTS
# pip install playsound==1.2.2
