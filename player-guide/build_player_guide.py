from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent
DOCX_PATH = ROOT / "ATM10-Space-Player-Setup.docx"
PDF_PATH = ROOT / "ATM10-Space-Player-Setup.pdf"
SPACE_MODS_URL = "https://github.com/chaaf3/atm10-space-server/blob/main/player-guide/ATM10-Space-Mods.zip?raw=1"


INK = RGBColor(25, 36, 54)
BLUE = RGBColor(31, 78, 121)
MUTED = RGBColor(89, 99, 114)
BORDER = "D9E2EC"
FILL = "F5F7FA"
CALLOUT = "EAF3FF"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def set_cell_border(cell, color=BORDER, size="6"):
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.append(borders)
    for edge in ("top", "left", "bottom", "right"):
        tag = "w:{}".format(edge)
        element = borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), color)


def set_cell_margins(table, top=80, start=120, bottom=80, end=120):
    tbl_pr = table._tbl.tblPr
    margins = tbl_pr.first_child_found_in("w:tblCellMar")
    if margins is None:
        margins = OxmlElement("w:tblCellMar")
        tbl_pr.append(margins)
    for side, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = margins.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            margins.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def add_paragraph(document, text="", style=None, bold_prefix=None):
    paragraph = document.add_paragraph(style=style)
    if bold_prefix and text.startswith(bold_prefix):
        run = paragraph.add_run(bold_prefix)
        run.bold = True
        paragraph.add_run(text[len(bold_prefix):])
    else:
        paragraph.add_run(text)
    return paragraph


def add_bullet(document, text):
    paragraph = document.add_paragraph(style="List Bullet")
    paragraph.add_run(text)
    return paragraph


def add_number(document, text):
    paragraph = document.add_paragraph(style="List Number")
    paragraph.add_run(text)
    return paragraph


def add_code_box(document, lines):
    table = document.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    set_cell_margins(table, top=120, bottom=120, start=180, end=180)
    cell = table.cell(0, 0)
    set_cell_shading(cell, "F1F5F9")
    set_cell_border(cell, color="CBD5E1")
    paragraph = cell.paragraphs[0]
    for index, line in enumerate(lines):
        if index:
            paragraph.add_run().add_break()
        run = paragraph.add_run(line)
        run.font.name = "Courier New"
        run.font.size = Pt(10)
        run.font.color.rgb = INK
    document.add_paragraph()


def add_note(document, title, body):
    table = document.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    set_cell_margins(table, top=120, bottom=120, start=180, end=180)
    cell = table.cell(0, 0)
    set_cell_shading(cell, CALLOUT)
    set_cell_border(cell, color="B7D7F5")
    paragraph = cell.paragraphs[0]
    run = paragraph.add_run(title)
    run.bold = True
    run.font.color.rgb = BLUE
    paragraph.add_run(" " + body)
    document.add_paragraph()


def add_two_col_table(document, rows):
    table = document.add_table(rows=1, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    table.autofit = False
    table.columns[0].width = Inches(2.2)
    table.columns[1].width = Inches(4.0)
    set_cell_margins(table)

    hdr = table.rows[0].cells
    hdr[0].text = "Computer RAM"
    hdr[1].text = "CurseForge Allocation"
    for cell in hdr:
        set_cell_shading(cell, FILL)
        set_cell_border(cell)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        for paragraph in cell.paragraphs:
            for run in paragraph.runs:
                run.bold = True
                run.font.color.rgb = INK

    for left, right in rows:
        cells = table.add_row().cells
        cells[0].text = left
        cells[1].text = right
        for cell in cells:
            set_cell_border(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER

    document.add_paragraph()


def style_document(document):
    section = document.sections[0]
    section.top_margin = Inches(0.75)
    section.bottom_margin = Inches(0.75)
    section.left_margin = Inches(0.8)
    section.right_margin = Inches(0.8)

    styles = document.styles
    normal = styles["Normal"]
    normal.font.name = "Arial"
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = INK
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.12

    for style_name, size, color, before, after in (
        ("Heading 1", 17, BLUE, 14, 5),
        ("Heading 2", 13, BLUE, 10, 4),
        ("Heading 3", 11.5, MUTED, 8, 3),
    ):
        style = styles[style_name]
        style.font.name = "Arial"
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = color
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)

    for style_name in ("List Bullet", "List Number"):
        style = styles[style_name]
        style.font.name = "Arial"
        style.font.size = Pt(10.5)
        style.paragraph_format.space_after = Pt(3)
        style.paragraph_format.left_indent = Inches(0.28)
        style.paragraph_format.first_line_indent = Inches(-0.18)


def build():
    document = Document()
    style_document(document)

    title = document.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = title.add_run("ATM10 Space Server Player Setup")
    run.font.name = "Arial"
    run.font.size = Pt(24)
    run.font.bold = True
    run.font.color.rgb = BLUE

    subtitle = document.add_paragraph()
    subtitle_run = subtitle.add_run("CurseForge install guide and whitelist request instructions")
    subtitle_run.font.name = "Arial"
    subtitle_run.font.size = Pt(11)
    subtitle_run.font.color.rgb = MUTED

    add_note(
        document,
        "Use the exact versions.",
        "Install ATM10 version 7.0 and use only the extra space mod files provided by the server admin. Version mismatches can stop you from joining.",
    )

    document.add_heading("What You Need", level=1)
    for item in (
        "Minecraft: Java Edition on the Microsoft account you play with.",
        "CurseForge app installed from curseforge.com/download/app.",
        "At least 16 GB of computer RAM. 32 GB is better.",
        "The server address from the server admin.",
        "The extra space mod .jar files from the server admin, if provided separately.",
    ):
        add_bullet(document, item)

    document.add_heading("Install ATM10 in CurseForge", level=1)
    for item in (
        "Open the CurseForge app.",
        "Choose Minecraft.",
        "Search for All the Mods 10 - ATM10.",
        "Install ATM10 version 7.0.",
        "Do not update the modpack unless the server admin says the server has been updated.",
    ):
        add_number(document, item)

    document.add_heading("Add the Space Mods", level=1)
    for item in (
        "Download ATM10-Space-Mods.zip from the GitHub link in this guide.",
        "Unzip ATM10-Space-Mods.zip.",
        "In CurseForge, click the ATM10 profile.",
        "Open the profile menu, usually shown as three dots.",
        "Choose Open Folder.",
        "Open the mods folder.",
        "Copy the .jar files from the unzipped bundle into the mods folder.",
        "Do not unzip the .jar files themselves.",
        "Launch the pack from CurseForge.",
    ):
        add_number(document, item)

    add_paragraph(
        document,
        "The bundle includes Stellaris and its required dependencies. Use only this bundle unless the admin sends a newer link.",
    )

    document.add_heading("Allocate Memory", level=1)
    add_two_col_table(
        document,
        [
            ("16 GB RAM", "Allocate 8-10 GB"),
            ("32 GB+ RAM", "Allocate 10-12 GB"),
        ],
    )
    add_paragraph(document, "Do not allocate all of your RAM. Your operating system still needs room.")

    document.add_heading("Join the Server", level=1)
    for item in (
        "Launch ATM10 from CurseForge.",
        "Choose Multiplayer.",
        "Add the server address from the admin.",
        "Join the server.",
    ):
        add_number(document, item)

    document.add_heading("Whitelist Request", level=1)
    add_paragraph(document, "Send the admin only this:")
    add_code_box(document, ["Minecraft Java username: YourNameHere"])
    add_paragraph(
        document,
        "Do not send your Microsoft email, password, Discord name, or Xbox gamertag unless it is also your Java username.",
    )
    add_paragraph(
        document,
        "Minecraft Java usernames are usually 3-16 characters and contain only letters, numbers, and underscores.",
    )
    add_code_box(
        document,
        [
            "Minecraft Java username: CoolPlayer_27",
            "Minecraft Java username: StoneBuilder",
        ],
    )

    document.add_heading("Quick Troubleshooting", level=1)
    for item in (
        "Wrong Minecraft version: launch directly from the ATM10 profile inside CurseForge.",
        "Startup crash: increase allocated memory within the recommended range and try again.",
        "Mod mismatch: reinstall ATM10 version 7.0 and replace the extra space mod files with the exact admin-provided files.",
        "Not whitelisted: double-check your Minecraft Java username and send it again.",
        "Authentication failed: restart Minecraft and make sure you are signed into the Microsoft account that owns Java Edition.",
    ):
        add_bullet(document, item)

    document.add_paragraph()
    footer = document.add_paragraph()
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer_run = footer.add_run("Server pack: ATM10 7.0 + Stellaris space mods")
    footer_run.font.size = Pt(9)
    footer_run.font.color.rgb = MUTED

    document.save(DOCX_PATH)


def wrap_text(pdf, text, max_width, font_name="Helvetica", font_size=9):
    words = text.split()
    lines = []
    line = ""
    for word in words:
        candidate = word if not line else f"{line} {word}"
        if pdf.stringWidth(candidate, font_name, font_size) <= max_width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def draw_wrapped(pdf, text, x, y, max_width, font_name="Helvetica", font_size=9, leading=11, color=colors.HexColor("#192436")):
    pdf.setFillColor(color)
    pdf.setFont(font_name, font_size)
    for line in wrap_text(pdf, text, max_width, font_name, font_size):
        pdf.drawString(x, y, line)
        y -= leading
    return y


def draw_section(pdf, title, items, x, y, width):
    pdf.setFillColor(colors.HexColor("#1F4E79"))
    pdf.setFont("Helvetica-Bold", 11)
    pdf.drawString(x, y, title)
    y -= 14
    for item in items:
        pdf.setFillColor(colors.HexColor("#192436"))
        pdf.setFont("Helvetica", 8.8)
        pdf.drawString(x, y, "-")
        y = draw_wrapped(pdf, item, x + 10, y, width - 10, font_size=8.8, leading=10)
        y -= 2
    return y - 4


def build_pdf():
    pdf = canvas.Canvas(str(PDF_PATH), pagesize=letter)
    page_width, page_height = letter
    margin = 0.55 * inch
    x = margin
    y = page_height - margin

    pdf.setFillColor(colors.HexColor("#1F4E79"))
    pdf.setFont("Helvetica-Bold", 21)
    pdf.drawString(x, y, "ATM10 Space Server Player Setup")
    y -= 18
    pdf.setFillColor(colors.HexColor("#596372"))
    pdf.setFont("Helvetica", 9.5)
    pdf.drawString(x, y, "CurseForge install guide + whitelist request instructions")
    y -= 18

    pdf.setFillColor(colors.HexColor("#EAF3FF"))
    pdf.roundRect(x, y - 35, page_width - 2 * margin, 34, 5, fill=1, stroke=0)
    y = draw_wrapped(
        pdf,
        "Use the exact versions: install ATM10 version 7.0 and use only the extra space mod files provided by the server admin.",
        x + 10,
        y - 13,
        page_width - 2 * margin - 20,
        font_name="Helvetica-Bold",
        font_size=9,
        leading=10,
        color=colors.HexColor("#192436"),
    )
    y -= 14

    col_gap = 0.28 * inch
    col_width = (page_width - 2 * margin - col_gap) / 2
    left_x = x
    right_x = x + col_width + col_gap
    left_y = y
    right_y = y

    left_y = draw_section(
        pdf,
        "1. Install ATM10 in CurseForge",
        [
            "Install the CurseForge app from curseforge.com/download/app.",
            "Open CurseForge, choose Minecraft, and search for All the Mods 10 - ATM10.",
            "Install ATM10 version 7.0.",
            "Do not update the pack unless the server admin says the server was updated.",
        ],
        left_x,
        left_y,
        col_width,
    )

    left_y = draw_section(
        pdf,
        "2. Add the Space Mods",
        [
            "Download ATM10-Space-Mods.zip from the GitHub link below.",
            "Unzip ATM10-Space-Mods.zip.",
            "Open the ATM10 profile menu, choose Open Folder, then open mods.",
            "Copy the .jar files from the unzipped bundle into mods. Do not unzip the .jar files themselves.",
        ],
        left_x,
        left_y,
        col_width,
    )

    pdf.setFillColor(colors.HexColor("#F5F7FA"))
    link_box_h = 66
    pdf.roundRect(left_x, left_y - link_box_h, col_width, link_box_h, 5, fill=1, stroke=0)
    link_y = left_y - 15
    pdf.setFillColor(colors.HexColor("#1F4E79"))
    pdf.setFont("Helvetica-Bold", 9.5)
    pdf.drawString(left_x + 10, link_y, "Space mod bundle download")
    link_y -= 14
    pdf.setFont("Helvetica-Bold", 9.2)
    pdf.setFillColor(colors.HexColor("#0B63B6"))
    link_label = "Download ATM10-Space-Mods.zip"
    pdf.drawString(left_x + 10, link_y, link_label)
    label_width = pdf.stringWidth(link_label, "Helvetica-Bold", 9.2)
    pdf.line(left_x + 10, link_y - 2, left_x + 10 + label_width, link_y - 2)
    pdf.linkURL(SPACE_MODS_URL, (left_x + 10, link_y - 4, left_x + 10 + label_width, link_y + 11), relative=0)
    link_y -= 14
    pdf.setFont("Helvetica", 8.2)
    pdf.setFillColor(colors.HexColor("#192436"))
    link_y = draw_wrapped(
        pdf,
        "Unzip it, then copy the .jar files into the ATM10 mods folder.",
        left_x + 10,
        link_y,
        col_width - 20,
        font_size=8.2,
        leading=9.5,
    )
    left_y -= link_box_h + 12

    left_y = draw_section(
        pdf,
        "3. Memory Settings",
        [
            "16 GB computer RAM: allocate 8-10 GB.",
            "32 GB+ computer RAM: allocate 10-12 GB.",
            "Do not allocate all your RAM; your operating system still needs room.",
        ],
        left_x,
        left_y,
        col_width,
    )

    right_y = draw_section(
        pdf,
        "4. Join the Server",
        [
            "Launch ATM10 from CurseForge.",
            "Choose Multiplayer.",
            "Add the server address from the admin.",
            "Join after your Minecraft Java username has been whitelisted.",
        ],
        right_x,
        right_y,
        col_width,
    )

    pdf.setFillColor(colors.HexColor("#F5F7FA"))
    box_h = 88
    pdf.roundRect(right_x, right_y - box_h, col_width, box_h, 5, fill=1, stroke=0)
    box_y = right_y - 16
    pdf.setFillColor(colors.HexColor("#1F4E79"))
    pdf.setFont("Helvetica-Bold", 11)
    pdf.drawString(right_x + 10, box_y, "Whitelist Request")
    box_y -= 17
    pdf.setFillColor(colors.HexColor("#192436"))
    pdf.setFont("Helvetica", 8.8)
    pdf.drawString(right_x + 10, box_y, "Send the admin only this:")
    box_y -= 16
    pdf.setFont("Courier", 8.5)
    pdf.drawString(right_x + 10, box_y, "Minecraft Java username: YourNameHere")
    box_y -= 16
    box_y = draw_wrapped(
        pdf,
        "Do not send your Microsoft email, password, Discord name, or Xbox gamertag unless it is also your Java username.",
        right_x + 10,
        box_y,
        col_width - 20,
        font_size=8.2,
        leading=9.5,
    )
    right_y -= box_h + 16

    right_y = draw_section(
        pdf,
        "Troubleshooting",
        [
            "Not whitelisted: resend your exact Minecraft Java username.",
            "Mod mismatch: reinstall ATM10 7.0 and replace the extra jars with the admin-provided files.",
            "Startup crash: increase memory within the recommended range.",
            "Authentication failed: restart Minecraft and confirm your Microsoft account owns Java Edition.",
        ],
        right_x,
        right_y,
        col_width,
    )

    pdf.setFillColor(colors.HexColor("#596372"))
    pdf.setFont("Helvetica", 7.8)
    pdf.drawCentredString(page_width / 2, 0.38 * inch, "Server pack: ATM10 7.0 + Stellaris space mods")
    pdf.save()


if __name__ == "__main__":
    build()
    build_pdf()
