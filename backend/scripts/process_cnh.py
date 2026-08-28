#!/usr/bin/env python3
"""
process_cnh.py

Processa PDF da CNH digital oficial (SENATRAN) e gera imagem WEBP otimizada.

Uso:
    python3 process_cnh.py input.pdf output.webp

Saída:
    - Imagem única vertical (frente + verso)
    - Formato WEBP
    - Tamanho ideal: 50-100 KB
    - Resolução: ~900-1000px de largura
"""

import sys
import os
import io

try:
    import fitz  # PyMuPDF
    from PIL import Image
except ImportError:
    print("Erro: Instale as dependências: pip install pymupdf pillow")
    sys.exit(1)


def process_cnh(input_path, output_path):
    # Abre PDF
    doc = fitz.open(input_path)
    
    if len(doc) < 1:
        print("Erro: PDF vazio")
        sys.exit(1)
    
    # Renderiza primeira página em alta resolução
    page = doc[0]
    mat = fitz.Matrix(3, 3)  # 3x zoom para qualidade
    pix = page.get_pixmap(matrix=mat)
    
    # Converte para PIL Image
    img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
    
    doc.close()
    
    # Dimensões da imagem renderizada
    w, h = img.size
    
    # Crop fixo baseado no PDF oficial SENATRAN (layout A4)
    # Análise visual da estrutura:
    # - Topo: faixa cinza "REPÚBLICA FEDERATIVA DO BRASIL" (~12%)
    # - Esquerda: CNH frente (foto, dados, categorias)
    # - Direita: QR Code grande + texto Serpro (remover)
    # - Inferior: CNH verso (texto, código de barras)
    
    # Remove: faixa topo, QR Code, texto Serpro, margens
    # Mantém: frente CNH (esquerda) + verso CNH (inferior)
    
    left   = int(w * 0.02)    # 2% margem esquerda
    top    = int(h * 0.12)    # 12% remove faixa cinza topo
    right  = int(w * 0.52)    # 52% remove QR Code e texto da direita
    bottom = int(h * 0.88)    # 88% remove rodapé inferior
    
    img_cropped = img.crop((left, top, right, bottom))
    
    # Redimensiona para largura ideal (900-1000px)
    target_width = 950
    ratio = target_width / img_cropped.width
    target_height = int(img_cropped.height * ratio)
    
    img_resized = img_cropped.resize((target_width, target_height), Image.LANCZOS)
    
    # Salva como WEBP com compressão progressiva
    quality = 70
    max_size_kb = 100
    
    while quality >= 40:
        buffer = io.BytesIO()
        img_resized.save(buffer, format="WEBP", quality=quality, method=6)
        size_kb = buffer.tell() / 1024
        
        if size_kb <= max_size_kb:
            with open(output_path, "wb") as f:
                f.write(buffer.getvalue())
            print(f"OK: {output_path} ({size_kb:.1f} KB, quality={quality})")
            return
        
        quality -= 5
    
    # Se ainda ultrapassar, reduz resolução
    target_width = 800
    ratio = target_width / img_cropped.width
    target_height = int(img_cropped.height * ratio)
    img_resized = img_cropped.resize((target_width, target_height), Image.LANCZOS)
    
    buffer = io.BytesIO()
    img_resized.save(buffer, format="WEBP", quality=60, method=6)
    with open(output_path, "wb") as f:
        f.write(buffer.getvalue())
    
    size_kb = buffer.tell() / 1024
    print(f"OK: {output_path} ({size_kb:.1f} KB, resolução reduzida)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 process_cnh.py input.pdf output.webp")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    if not os.path.exists(input_path):
        print(f"Erro: Arquivo não encontrado: {input_path}")
        sys.exit(1)
    
    process_cnh(input_path, output_path)
