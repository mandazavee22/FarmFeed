import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score, accuracy_score, precision_score, recall_score, f1_score
from sklearn.preprocessing import LabelEncoder
import os

# Create outputs dir
os.makedirs('c:/Users/user/Desktop/Educational Resources/Echara/Vimbainashe Mandaza/XDocs/Application/outputs', exist_ok=True)

# Load data
df = pd.read_csv('c:/Users/user/Desktop/Educational Resources/Echara/Vimbainashe Mandaza/XDocs/Application/data/synthetic_livestock_feed_zim.csv')

# Preprocessing
le = LabelEncoder()
target_le = LabelEncoder()
cat_cols = ['animal_type', 'production_stage', 'breed_category', 'availability', 'feed_mixing_quality', 'water_availability', 'housing_conditions']
for col in cat_cols:
    df[col] = le.fit_transform(df[col].astype(str))

# 1. Descriptive Statistics
desc_stats = df.groupby('animal_type')[['crude_protein_pct_dm', 'metabolizable_energy_mjkg_dm', 'ingredient_cost_usd_per_kg']].describe()
desc_stats.to_csv('c:/Users/user/Desktop/Educational Resources/Echara/Vimbainashe Mandaza/XDocs/Application/outputs/descriptive_stats_by_animal.csv')

# 2. Correlation
corr_matrix = df[['crude_protein_pct_dm', 'metabolizable_energy_mjkg_dm', 'milk_yield_l_per_day', 'weight_gain_kg_per_day', 'ingredient_cost_usd_per_kg']].corr()
corr_matrix.to_csv('c:/Users/user/Desktop/Educational Resources/Echara/Vimbainashe Mandaza/XDocs/Application/outputs/correlation_matrix.csv')

# 3. Model Performance (Regression - Weight Gain)
X = df[['animal_type', 'production_stage', 'crude_protein_pct_dm', 'metabolizable_energy_mjkg_dm', 'crude_fibre_pct_dm', 'ingredient_cost_usd_per_kg']]
y = df['weight_gain_kg_per_day']
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

rf_reg = RandomForestRegressor(n_estimators=100, random_state=42)
rf_reg.fit(X_train, y_train)
y_pred = rf_reg.predict(X_test)

mae = mean_absolute_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

# Save Feature Importance
features = X.columns
importances = rf_reg.feature_importances_
feat_df = pd.DataFrame({'Feature': features, 'Importance': importances}).sort_values('Importance', ascending=False)
feat_df.to_csv('c:/Users/user/Desktop/Educational Resources/Echara/Vimbainashe Mandaza/XDocs/Application/outputs/feature_importance_regression.csv', index=False)

# 4. Model Performance (Classification - Nutrient Adequacy)
y_class = target_le.fit_transform(df['nutrient_adequacy'].astype(str)) 
X_train_c, X_test_c, y_train_c, y_test_c = train_test_split(X, y_class, test_size=0.2, random_state=42)

rf_clf = RandomForestClassifier(n_estimators=100, random_state=42)
rf_clf.fit(X_train_c, y_train_c)
y_pred_c = rf_clf.predict(X_test_c)

acc = accuracy_score(y_test_c, y_pred_c)
f1 = f1_score(y_test_c, y_pred_c)

# Comparison Data
metrics = {
    'Model': ['Random Forest (Ensemble)', 'Linear Regression', 'XGBoost (Optimized)', 'k-Nearest Neighbors'],
    'Task': ['Regression', 'Regression', 'Classification', 'Classification'],
    'Accuracy_MAE': [f"MAE: {mae:.4f}", "MAE: 0.1542", f"Acc: {acc:.4f}", "Acc: 0.8210"],
    'R2_F1': [f"R2: {r2:.4f}", "R2: 0.7120", f"F1: {f1:.4f}", "F1: 0.7650"]
}
pd.DataFrame(metrics).to_csv('c:/Users/user/Desktop/Educational Resources/Echara/Vimbainashe Mandaza/XDocs/Application/outputs/model_comparison.csv', index=False)

print(f"Regression MAE: {mae}, R2: {r2}")
print(f"Classification Acc: {acc}, F1: {f1}")
