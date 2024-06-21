import joblib
import pandas as pd
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Load the dataset
df = pd.read_csv('Haircut_Dataset.csv')

# Correct column names based on your dataset
corrected_columns = {
    'genderHaircut': 'Gender Haircut',
    'hairLength': 'Hair Length',
    'faceShape': 'Face Shape',
    'hairType': 'Hair Type',
    'hairDensity': 'Hair Density',
    'recommendedHaircut': 'Recommended Haircut'
}

# Load the model
try:
    model = joblib.load('model.pkl')
except Exception as e:
    print(f"Error loading the model: {e}")
    model = None

# Generate lists for each attribute
genderHaircutList = list(set(df[corrected_columns['genderHaircut']].values.tolist()))
hairLengthList = list(set(df[corrected_columns['hairLength']].values.tolist()))
faceShapeList = list(set(df[corrected_columns['faceShape']].values.tolist()))
hairTypeList = list(set(df[corrected_columns['hairType']].values.tolist()))
hairDensityList = list(set(df[corrected_columns['hairDensity']].values.tolist()))

# Define routes to return the lists
@app.route('/genderHaircut')
def genderHaircut():
    return jsonify({"genderHaircutList": genderHaircutList})

@app.route('/hairLength')
def hairLength():
    return jsonify({"hairLengthList": hairLengthList})

@app.route('/faceShape')
def faceShape():
    return jsonify({"faceShapeList": faceShapeList})

@app.route('/hairType')
def hairType():
    return jsonify({"hairTypeList": hairTypeList})

@app.route('/hairDensity')
def hairDensity():
    return jsonify({"hairDensityList": hairDensityList})

# Mappings for categorical variables
gender_mapping = {'Male': 0, 'Female': 1}
hair_length_mapping = {'Short': 0, 'Medium': 1, 'Long': 2}
face_shape_mapping = {'Oval': 0, 'Round': 1, 'Square': 2, 'Heart': 3, 'Diamond': 4}
hair_type_mapping = {'Straight': 0, 'Wavy': 1, 'Curly': 2}
hair_density_mapping = {'Thin': 0, 'Medium': 1, 'Thick': 2}

def preprocess_input(data):
    return {
        'Gender Haircut': gender_mapping[data['Gender Haircut']],
        'Hair Length': hair_length_mapping[data['Hair Length']],
        'Face Shape': face_shape_mapping[data['Face Shape']],
        'Hair Type': hair_type_mapping[data['Hair Type']],
        'Hair Density': hair_density_mapping[data['Hair Density']]
    }

# Prediction route
@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({"error": "Model not loaded"}), 500

    try:
        data = request.json['features']

        # Validate the input data
        required_features = ['Gender Haircut', 'Hair Length', 'Face Shape', 'Hair Type', 'Hair Density']
        for feature in required_features:
            if feature not in data:
                return jsonify({"error": f"Missing feature: {feature}"}), 400

        input_data = preprocess_input(data)
        input_df = pd.DataFrame([input_data])  # Create a DataFrame with the input data
        prediction = model.predict(input_df)
        return jsonify({"prediction": prediction.tolist()[0]})
    except Exception as e:
        app.logger.error(f"Error during prediction: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5001, debug=True)
