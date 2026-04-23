import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score

# ==========================================
# 1. CARREGAMENTO DOS DADOS
# ==========================================
# Substitua pelo caminho onde você salvou o seu CSV
caminho_csv = r'C:\Users\rafin\OneDrive\Área de Trabalho\IC_offline\Dataset_Motores_ARX.csv'

print("Carregando o dataset...")
df = pd.read_csv(caminho_csv)

# Exibe as primeiras linhas para confirmar a leitura
print(f"Dataset carregado com {df.shape[0]} amostras e {df.shape[1]} colunas.")

# ==========================================
# 2. SEPARAÇÃO DE FEATURES (X) E ALVOS (y)
# ==========================================
# Removemos a coluna 'Arquivo' pois é apenas texto de identificação e não um dado matemático
# Removemos 'Classe' pois é o que queremos prever (o gabarito)
X = df.drop(columns=['Arquivo', 'Classe'])
y = df['Classe']

# ==========================================
# 3. DIVISÃO EM TREINO E TESTE
# ==========================================
# Separamos 70% dos dados para o modelo "estudar" e 30% para aplicarmos a "prova final"
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42, stratify=y)
print(f"Amostras para Treino: {len(X_train)} | Amostras para Teste: {len(X_test)}")

# ==========================================
# 4. PADRONIZAÇÃO DOS DADOS (Z-Score Scaling)
# ==========================================
# Coloca todos os Thetas na mesma escala (Média 0 e Desvio Padrão 1)
# O scaler "aprende" com o treino e apenas "aplica" no teste (simulando a vida real)
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# ==========================================
# 5. TREINAMENTO DO MODELO (RANDOM FOREST)
# ==========================================
print("\nTreinando o modelo de Machine Learning (Random Forest)...")
modelo = RandomForestClassifier(n_estimators=100, random_state=42)
modelo.fit(X_train_scaled, y_train)

# ==========================================
# 6. AVALIAÇÃO DO MODELO (A PROVA FINAL)
# ==========================================
print("\nAplicando o modelo nos dados de teste ocultos...")
y_pred = modelo.predict(X_test_scaled)

acuracia = accuracy_score(y_test, y_pred)
print(f"\n>>> ACURÁCIA GERAL DO SISTEMA: {acuracia * 100:.2f}% <<<")

print("\nRelatório de Classificação Detalhado:")
print(classification_report(y_test, y_pred))

# ==========================================
# 7. VISUALIZAÇÕES
# ==========================================
plt.figure(figsize=(14, 6))

# Gráfico 1: Matriz de Confusão
plt.subplot(1, 2, 1)
cm = confusion_matrix(y_test, y_pred, labels=modelo.classes_)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=modelo.classes_, yticklabels=modelo.classes_)
plt.title('Matriz de Confusão (Acertos vs Erros)')
plt.xlabel('Previsão da Máquina')
plt.ylabel('Falha Real (Gabarito)')
plt.xticks(rotation=45)

# Gráfico 2: Importância das Features (Qual parâmetro o ML achou mais útil?)
plt.subplot(1, 2, 2)
importancias = modelo.feature_importances_
indices = np.argsort(importancias)[::-1] # Ordena do maior pro menor
nomes_features = X.columns

sns.barplot(x=importancias[indices], y=[nomes_features[i] for i in indices], palette='viridis')
plt.title('Importância dos Parâmetros ARX (Feature Importance)')
plt.xlabel('Nível de Importância')
plt.ylabel('Parâmetro')

plt.tight_layout()
plt.show()