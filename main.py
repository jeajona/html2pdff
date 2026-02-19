import os
import zipfile
from bs4 import BeautifulSoup
from fpdf import FPDF

from kivy.app import App
from kivy.uix.button import Button
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from plyer import filechooser


class CeviriciApp(App):

    def build(self):
        self.layout = BoxLayout(orientation="vertical", padding=20, spacing=20)

        self.label = Label(text="ZIP dosyası seçin")
        self.button = Button(text="ZIP Seç ve PDF'e Dönüştür")
        self.button.bind(on_press=self.select_file)

        self.layout.add_widget(self.label)
        self.layout.add_widget(self.button)

        return self.layout

    def select_file(self, instance):
        filechooser.open_file(on_selection=self.process_file)

    def process_file(self, selection):
        if not selection:
            return

        zip_path = selection[0]
        base_folder = os.path.dirname(zip_path)
        extract_folder = os.path.join(base_folder, "extracted")

        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_folder)

            for root, dirs, files in os.walk(extract_folder):
                for file in files:
                    if file.endswith(".html"):
                        html_path = os.path.join(root, file)

                        with open(html_path, "r", encoding="utf-8", errors="ignore") as f:
                            soup = BeautifulSoup(f.read(), "html.parser")

                        text = soup.get_text()

                        pdf = FPDF()
                        pdf.add_page()
                        pdf.add_font("DejaVu", "", "DejaVuSans.ttf", True)
                        pdf.set_font("DejaVu", size=10)
                        pdf.multi_cell(0, 5, text)

                        pdf_path = os.path.join(base_folder, file.replace(".html", ".pdf"))
                        pdf.output(pdf_path)

            self.label.text = "PDF oluşturuldu ✅"

        except Exception as e:
            self.label.text = f"Hata: {str(e)}"


CeviriciApp().run()