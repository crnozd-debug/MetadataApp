# -*- coding: utf-8 -*-
"""
thesis_draft.md içeriğini tezbeta.docx şablonuna aktaran script.
Şablonun sayfa boyutu, marjinler, font ve stil ayarlarını koruyarak
içeriğini tamamen thesis_draft.md ile değiştirir.
"""

from docx import Document
from docx.shared import Pt, Cm, Twips
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml.ns import qn
import os
import re

# ─── Yollar ───
BASE = r"c:\metadataapp\tez"
TEMPLATE = os.path.join(BASE, "tezbeta.docx")
OUTPUT   = os.path.join(BASE, "tezbeta.docx")
DRAFT    = os.path.join(BASE, "thesis_draft.md")

# ─── Draft'ı oku ───
with open(DRAFT, "r", encoding="utf-8") as f:
    draft_lines = f.readlines()

# ─── Draft parse et ───
sections = []
current_section = None

for line in draft_lines:
    line = line.rstrip('\r\n')
    
    if line.startswith('# ') and not line.startswith('## '):
        current_section = {'type': 'title', 'text': line[2:].strip(), 'content': []}
        sections.append(current_section)
    elif line.startswith('## ') and not line.startswith('### '):
        current_section = {'type': 'h1', 'text': line[3:].strip(), 'content': []}
        sections.append(current_section)
    elif line.startswith('### ') and not line.startswith('#### '):
        current_section = {'type': 'h2', 'text': line[4:].strip(), 'content': []}
        sections.append(current_section)
    elif line.startswith('#### '):
        current_section = {'type': 'h3', 'text': line[5:].strip(), 'content': []}
        sections.append(current_section)
    elif line.strip() == '---':
        continue
    elif current_section is not None:
        current_section['content'].append(line)

# ─── Dokümanı aç ve tüm içeriği sil ───
doc = Document(TEMPLATE)
body = doc.element.body

# Son sectPr'yi (sayfa ayarları) sakla
last_sect = None
for child in list(body):
    if child.tag.endswith('}sectPr'):
        last_sect = child
        continue
    body.remove(child)

# ─── Yardımcı fonksiyonlar ───

def make_run(paragraph, text, bold=False, font_size=Pt(12), italic=False, font_name='Times New Roman'):
    """Formatlı run oluştur"""
    run = paragraph.add_run(text)
    run.bold = bold
    run.font.name = font_name
    run.font.size = font_size
    if italic:
        run.italic = True
    # Türkçe karakter desteği için cs font
    rpr = run._element.get_or_add_rPr()
    rFonts = rpr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = run._element.makeelement(qn('w:rFonts'), {})
        rpr.insert(0, rFonts)
    rFonts.set(qn('w:cs'), font_name)
    rFonts.set(qn('w:eastAsia'), font_name)
    return run

def add_formatted_runs(paragraph, text, bold=False, font_size=Pt(12), italic=False):
    """Markdown inline formatting: **bold**, `code` destekli metin ekle"""
    # **bold** kısımlarını ayır
    parts = re.split(r'(\*\*.*?\*\*)', text)
    for part in parts:
        if part.startswith('**') and part.endswith('**'):
            clean = part[2:-2].replace('`', '')
            make_run(paragraph, clean, bold=True, font_size=font_size, italic=italic)
        elif part:
            clean = part.replace('`', '')
            make_run(paragraph, clean, bold=bold, font_size=font_size, italic=italic)

def add_para(doc, text='', bold=False, font_size=Pt(12), alignment=None,
             space_before=None, space_after=None, first_line_indent=None,
             line_spacing=None, left_indent=None, right_indent=None,
             style_name='Normal', italic=False, formatted=False):
    """Paragraf ekle ve formatla"""
    p = doc.add_paragraph()
    try:
        p.style = doc.styles[style_name]
    except:
        p.style = doc.styles['Normal']
    
    pf = p.paragraph_format
    if alignment is not None:
        p.alignment = alignment
    if space_before is not None:
        pf.space_before = space_before
    if space_after is not None:
        pf.space_after = space_after
    if first_line_indent is not None:
        pf.first_line_indent = first_line_indent
    if line_spacing is not None:
        pf.line_spacing = line_spacing
    if left_indent is not None:
        pf.left_indent = left_indent
    if right_indent is not None:
        pf.right_indent = right_indent
    
    if text:
        if formatted:
            add_formatted_runs(p, text, bold=bold, font_size=font_size, italic=italic)
        else:
            make_run(p, text, bold=bold, font_size=font_size, italic=italic)
    return p

def page_break(doc):
    """Sayfa sonu ekle"""
    p = doc.add_paragraph()
    run = p.add_run()
    run.add_break(WD_BREAK.PAGE)
    return p

def body_para(doc, text, formatted=True):
    """Standart gövde paragrafı - 1.5 satır, justified, first-line indent"""
    return add_para(doc, text, style_name='Body Text',
                    font_size=Pt(12), 
                    alignment=WD_ALIGN_PARAGRAPH.JUSTIFY,
                    space_before=Pt(6), space_after=Pt(6),
                    first_line_indent=Cm(1.25),
                    line_spacing=1.5,
                    left_indent=Cm(0),
                    formatted=formatted)

def bullet_item(doc, text, indent_cm=1.5):
    """Madde işaretli liste öğesi"""
    p = add_para(doc, '', style_name='Normal',
                 alignment=WD_ALIGN_PARAGRAPH.JUSTIFY,
                 space_before=Pt(3), space_after=Pt(3),
                 line_spacing=1.5,
                 left_indent=Cm(indent_cm))
    make_run(p, '• ', font_size=Pt(12))
    add_formatted_runs(p, text, font_size=Pt(12))
    return p

def dash_item(doc, text, indent_cm=2.0):
    """Alt madde (– işaretli)"""
    p = add_para(doc, '', style_name='Normal',
                 alignment=WD_ALIGN_PARAGRAPH.JUSTIFY,
                 space_before=Pt(2), space_after=Pt(2),
                 line_spacing=1.5,
                 left_indent=Cm(indent_cm))
    make_run(p, '– ', font_size=Pt(12))
    add_formatted_runs(p, text, font_size=Pt(12))
    return p

def numbered_item(doc, num, text, indent_cm=1.5):
    """Numaralı liste öğesi"""
    p = add_para(doc, '', style_name='Normal',
                 alignment=WD_ALIGN_PARAGRAPH.JUSTIFY,
                 space_before=Pt(4), space_after=Pt(4),
                 line_spacing=1.5,
                 left_indent=Cm(indent_cm))
    make_run(p, f'{num}.  ', bold=True, font_size=Pt(12))
    add_formatted_runs(p, text, font_size=Pt(12))
    return p

def process_content(doc, content_lines):
    """İçerik satırlarını işle: paragraf, liste, alt-liste"""
    i = 0
    while i < len(content_lines):
        line = content_lines[i]
        stripped = line.strip()
        
        if not stripped:
            i += 1
            continue
        
        # Madde işaretli (*   veya - )
        if stripped.startswith('*   ') or (stripped.startswith('- ') and not stripped.startswith('---')):
            prefix_len = 4 if stripped.startswith('*   ') else 2
            item_text = stripped[prefix_len:]
            # Devam satırlarını birleştir
            while i + 1 < len(content_lines):
                nxt = content_lines[i+1].strip()
                if nxt and not nxt.startswith('*   ') and not nxt.startswith('- ') and not nxt.startswith('#') and not re.match(r'^\d+\.\s', nxt):
                    item_text += ' ' + nxt
                    i += 1
                else:
                    break
            bullet_item(doc, item_text)
            i += 1
            continue
        
        # Alt madde (    - veya boşlukla başlayan -)
        if re.match(r'^    -\s', line) or re.match(r'^  -\s', line):
            item_text = re.sub(r'^[\s\-]+', '', line).strip()
            while i + 1 < len(content_lines):
                nxt = content_lines[i+1].strip()
                if nxt and not re.match(r'^[\s]*[\-\*]', content_lines[i+1]) and not nxt.startswith('#'):
                    item_text += ' ' + nxt
                    i += 1
                else:
                    break
            dash_item(doc, item_text)
            i += 1
            continue
        
        # Numaralı liste
        num_match = re.match(r'^(\d+)\.\s+', stripped)
        if num_match:
            num = num_match.group(1)
            item_text = stripped[len(num_match.group(0)):]
            while i + 1 < len(content_lines):
                nxt = content_lines[i+1].strip()
                if nxt and not re.match(r'^\d+\.\s', nxt) and not nxt.startswith('*') and not nxt.startswith('- ') and not nxt.startswith('#'):
                    item_text += ' ' + nxt
                    i += 1
                else:
                    break
            numbered_item(doc, num, item_text)
            i += 1
            continue
        
        # Normal paragraf - çok satırlıları birleştir
        para_text = stripped
        while i + 1 < len(content_lines):
            nxt = content_lines[i+1].strip()
            if (nxt and 
                not nxt.startswith('*   ') and 
                not nxt.startswith('- ') and
                not nxt.startswith('#') and
                not re.match(r'^\d+\.\s', nxt) and
                not re.match(r'^    -', content_lines[i+1])):
                para_text += ' ' + nxt
                i += 1
            else:
                break
        
        body_para(doc, para_text, formatted=True)
        i += 1


# ═══════════════════════════════════════════════════════════════
# KAPAK SAYFASI
# ═══════════════════════════════════════════════════════════════

add_para(doc, 'T.C.', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(60))

add_para(doc, 'OSMANİYE KORKUT ATA ÜNİVERSİTESİ', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(6), space_after=Pt(0))

add_para(doc, 'BİLGİSAYAR MÜHENDİSLİĞİ BÖLÜMÜ', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(6), space_after=Pt(0))

# Boşluk
for _ in range(3):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, 'BMB 490 BİTİRME TEZİ', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(12))

for _ in range(2):
    add_para(doc, '', space_before=Pt(12))

THESIS_TITLE = "METADATA MANAGER: MOBİL CİHAZLAR İÇİN ÇEVRİMDIŞI VE KAPSAMLI ÜSTVERİ YÖNETİMİ VE GİZLİLİK UYGULAMASI"

add_para(doc, THESIS_TITLE, bold=True, font_size=Pt(16),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(24), space_after=Pt(12))

for _ in range(4):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, 'Hazırlayan:', bold=True, font_size=Pt(12),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(12))
add_para(doc, '[ÖĞRENCİ ADI SOYADI]', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(6))

for _ in range(2):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, 'Danışman:', bold=True, font_size=Pt(12),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(12))
add_para(doc, '[DANIŞMAN UNVAN VE ADI SOYADI]', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(6))

for _ in range(3):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, 'OSMANİYE – [YIL]', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(12))


# ═══════════════════════════════════════════════════════════════
# İÇ KAPAK SAYFASI
# ═══════════════════════════════════════════════════════════════
page_break(doc)

add_para(doc, 'T.C.', bold=True, font_size=Pt(16),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(40))
add_para(doc, 'OSMANİYE KORKUT ATA ÜNİVERSİTESİ', bold=True, font_size=Pt(16),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(0))
add_para(doc, 'BİLGİSAYAR MÜHENDİSLİĞİ BÖLÜMÜ', bold=True, font_size=Pt(16),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(0))
add_para(doc, 'BMB 490 BİTİRME TEZİ', bold=True, font_size=Pt(16),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(0))

for _ in range(5):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, THESIS_TITLE, bold=True, font_size=Pt(16),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(24))

for _ in range(8):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, 'Hazırlayan: [ÖĞRENCİ ADI SOYADI]', bold=True, font_size=Pt(12),
         alignment=WD_ALIGN_PARAGRAPH.LEFT, space_before=Pt(6), left_indent=Cm(2))
add_para(doc, 'Danışman: [DANIŞMAN UNVAN VE ADI SOYADI]', bold=True, font_size=Pt(12),
         alignment=WD_ALIGN_PARAGRAPH.LEFT, space_before=Pt(6), left_indent=Cm(2))

for _ in range(4):
    add_para(doc, '', space_before=Pt(12))

add_para(doc, 'OSMANİYE – [YIL]', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(12))


# ═══════════════════════════════════════════════════════════════
# ONAY SAYFASI
# ═══════════════════════════════════════════════════════════════
page_break(doc)

add_para(doc, 'ONAY SAYFASI', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(30), space_after=Pt(18))

onay_text = ('[ÖĞRENCİ ADI SOYADI] tarafından hazırlanan '
             '"Metadata Manager: Mobil Cihazlar İçin Çevrimdışı ve Kapsamlı Üstveri Yönetimi ve Gizlilik Uygulaması" '
             'adlı çalışma, jürimiz tarafından Bilgisayar Mühendisliği Bölümü\'nde '
             'Bitirme Tezi olarak kabul edilmiştir.')
body_para(doc, onay_text, formatted=False)

for _ in range(4):
    add_para(doc, '', space_before=Pt(18))

# Jüri imza alanları
for label in ['Danışman:', 'Jüri Üyesi:', 'Jüri Üyesi:']:
    add_para(doc, '', space_before=Pt(36))
    add_para(doc, label, bold=True, font_size=Pt(12),
             alignment=WD_ALIGN_PARAGRAPH.LEFT, left_indent=Cm(1))
    add_para(doc, '[Unvan Ad Soyad]', font_size=Pt(12),
             alignment=WD_ALIGN_PARAGRAPH.LEFT, left_indent=Cm(1))
    add_para(doc, 'İmza: _______________', font_size=Pt(12),
             alignment=WD_ALIGN_PARAGRAPH.LEFT, left_indent=Cm(1), space_before=Pt(6))

add_para(doc, '', space_before=Pt(36))
add_para(doc, 'Tarih: …../…../…….', font_size=Pt(12),
         alignment=WD_ALIGN_PARAGRAPH.LEFT, left_indent=Cm(1))


# ═══════════════════════════════════════════════════════════════
# İÇİNDEKİLER
# ═══════════════════════════════════════════════════════════════
page_break(doc)

add_para(doc, 'İÇİNDEKİLER', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(30), space_after=Pt(24))

toc_items = [
    (0, 'ÖZET'),
    (0, '1. GİRİŞ'),
    (1, '1.1. Metadata Nedir?'),
    (1, '1.2. Metadata\'nın Tarihçesi'),
    (0, '2. DOSYA YAPILARI VE METADATA DEPOLAMA MİMARİSİ'),
    (1, '2.1. Metadata İçerebilecek Dosya Türleri'),
    (1, '2.2. Dosya Türlerinin Genel Yapısı: Bit Düzeyinde İnceleme'),
    (1, '2.3. Dosyalarda Metadata Konumları ve Çıkarım Yöntemleri (Reader Motoru)'),
    (0, '3. METADATA VE BİLGİ GÜVENLİĞİ'),
    (1, '3.1. Metadatanın Gizlilikteki Önemi ve Kötü Niyetli Kullanımı'),
    (1, '3.2. Dijital Adli Bilişim (Forensics) ve Analiz'),
    (0, '4. ÖNERİLEN ÇÖZÜM: METADATA MANAGER UYGULAMASI'),
    (1, '4.1. Uygulamanın Temel İşlevleri ve Çekirdek Motorları'),
    (1, '4.2. Uygulamanın Öne Çıkan Özellikleri ve Literatürdeki Farkı'),
    (2, '4.2.1. Yerel (Çevrimdışı) İşleme ve Mutlak Gizlilik'),
    (2, '4.2.2. Kapsamlı ve Özyineli Arşiv (ZIP) İşleme Yeteneği'),
    (2, '4.2.3. Son Kullanıcı Odaklı Basit ve Anlaşılır Arayüz'),
    (2, '4.2.4. Mobil Ekosistem Odaklılık ve Taşınabilirlik'),
    (2, '4.2.5. Hibrit Mimari ve Platform Optimizasyonu'),
    (0, '5. SONUÇ'),
]

for level, text in toc_items:
    is_bold = level == 0
    indent = Cm(level * 1.0)
    sb = Pt(6) if level == 0 else Pt(3)
    p = add_para(doc, text, bold=is_bold, font_size=Pt(12),
                 alignment=WD_ALIGN_PARAGRAPH.LEFT,
                 space_before=sb, space_after=Pt(2),
                 left_indent=indent)


# ═══════════════════════════════════════════════════════════════
# ÖZET
# ═══════════════════════════════════════════════════════════════
page_break(doc)

add_para(doc, 'ÖZET', bold=True, font_size=Pt(14),
         alignment=WD_ALIGN_PARAGRAPH.CENTER, space_before=Pt(30), space_after=Pt(18))

# Özet içeriğini draft'tan al
ozet_section = None
for s in sections:
    if s['type'] == 'h1' and 'Özet' in s['text']:
        ozet_section = s
        break

if ozet_section:
    ozet_text = ' '.join([l.strip() for l in ozet_section['content'] if l.strip()])
    body_para(doc, ozet_text, formatted=True)


# ═══════════════════════════════════════════════════════════════
# ANA BÖLÜMLER
# ═══════════════════════════════════════════════════════════════

for section in sections:
    if section['type'] == 'title':
        continue  # Ana başlık kapakta zaten
    if section['type'] == 'h1' and 'Özet' in section['text']:
        continue  # Özet zaten eklendi
    
    # ── Bölüm Başlığı (## → Heading 1, her bölüm yeni sayfada) ──
    if section['type'] == 'h1':
        page_break(doc)
        heading = section['text'].upper()
        add_para(doc, heading, bold=True, font_size=Pt(14),
                 alignment=WD_ALIGN_PARAGRAPH.CENTER,
                 space_before=Pt(30), space_after=Pt(18),
                 style_name='Heading 1')
    
    # ── Alt Bölüm Başlığı (### → Heading 2) ──
    elif section['type'] == 'h2':
        add_para(doc, section['text'], bold=True, font_size=Pt(12),
                 alignment=WD_ALIGN_PARAGRAPH.LEFT,
                 space_before=Pt(18), space_after=Pt(12),
                 left_indent=Cm(0),
                 style_name='Heading 2')
    
    # ── Alt-Alt Bölüm Başlığı (#### → Bold normal) ──
    elif section['type'] == 'h3':
        add_para(doc, section['text'], bold=True, font_size=Pt(12),
                 alignment=WD_ALIGN_PARAGRAPH.LEFT,
                 space_before=Pt(14), space_after=Pt(8),
                 left_indent=Cm(0))
    
    # İçerik satırlarını ekle
    if section['content']:
        process_content(doc, section['content'])


# ═══════════════════════════════════════════════════════════════
# SAYFA AYARLARI
# ═══════════════════════════════════════════════════════════════
for sec in doc.sections:
    sec.page_width  = Cm(21.0)   # A4
    sec.page_height = Cm(29.7)   # A4
    sec.top_margin    = Cm(2.5)
    sec.bottom_margin = Cm(2.5)
    sec.left_margin   = Cm(3.0)
    sec.right_margin  = Cm(1.75)

# ─── Kaydet ───
doc.save(OUTPUT)
print(f"[OK] Tez basariyla olusturuldu: {OUTPUT}")
print(f"  Toplam paragraf: {len(doc.paragraphs)}")

# Kontrol: Bolum basliklari listele
print("\n-- Bolum yapisi --")
for p in doc.paragraphs:
    text = p.text.strip()
    if not text:
        continue
    if p.style.name in ('Heading 1', 'Heading 2') or (p.runs and p.runs[0].bold and len(text) < 100 and text.isupper()):
        print(f"  [{p.style.name}] {text[:80]}")
