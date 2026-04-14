import serial
import csv
import time
import os

# Cria a pasta se não existir
caminho = r"C:\node-red"
if not os.path.exists(caminho):
    os.makedirs(caminho)

arquivo_csv = os.path.join(caminho, "dados.csv")

# Configuração da Serial (ajuste a porta COM e baudrate)
ser = serial.Serial("COM9", 2000000, timeout=1)
time.sleep(2)  # espera inicial

print("Gravando dados em", arquivo_csv)

# Abre arquivo CSV
with open(arquivo_csv, mode='w', newline='') as file:
    writer = csv.writer(file)
    
    # Cabeçalho
    writer.writerow(["Tensao","Corrente"])
    
    try:
        while True:
            linha = ser.readline().decode('utf-8').strip()
            if linha:
                # Espera o formato "tensao,corrente"
                dados = linha.split(',')
                if len(dados) == 2:
                    writer.writerow(dados)
                    print(dados)
    except KeyboardInterrupt:
        print("Gravação finalizada.")
        ser.close()