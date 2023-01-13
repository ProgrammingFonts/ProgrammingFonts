import os
from PIL import Image, ImageFont, ImageDraw
font_folder = 'fonts'
path = os.path.join(os.path.dirname(__file__), font_folder)

for font_file in os.listdir(path):
    if font_file.endswith('.ttf') or font_file.endswith('.otf'):
        font = ImageFont.truetype(os.path.join(path, font_file), 36)
        font_name, _ = os.path.splitext(font_file)
    
        # Create a new image with a black background
        img = Image.new("RGB", (800, 400), (0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.text((10, 10), f"""Sample Text\n1234567890\nABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n!@#$%%^&*()_+-=|{{}}[]':;<>,.?"
                            \n\nFont: {font_file}\nAuthor: ifeegoo\nScript: DiluteOxygen""", font=font, fill=(255, 255, 255))

        img.save(os.path.join(path, f"preview_{font_name}_black.jpg"))
        
        # Create a new image with a white background
        img = Image.new("RGB", (800, 400), (255, 255, 255))
        draw = ImageDraw.Draw(img)
        draw.text((10, 10), f"""Sample Text\n1234567890\nABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n!@#$%%^&*()_+-=|{{}}[]':;<>,.?"
                            \n\nFont: {font_file}\nAuthor: ifeegoo\nScript: DiluteOxygen""", font=font, fill=(0, 0, 0))

        img.save(os.path.join(path, f"preview_{font_name}_white.jpg"))
