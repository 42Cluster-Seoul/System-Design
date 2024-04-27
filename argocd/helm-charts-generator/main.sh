# Variables 
OUTPUT_DIRECTORY="output"
HELM_TEMPLATES_DIRECTORY="template/templates"

if [ ! -d "$OUTPUT_DIRECTORY" ]; then
  mkdir -p "$OUTPUT_DIRECTORY"
fi

read -p "Enter the value for application name: " app_name
sed "s/\${app_name}/$app_name/g" template/Charts.yaml.template > $OUTPUT_DIRECTORY/Charts.yaml

read -p "Enter image url: " image_url
sed "s/\${image_url}/$image_url/g" template/values.yaml.template > $OUTPUT_DIRECTORY/values.yaml

cp -r "$HELM_TEMPLATES_DIRECTORY" "$OUTPUT_DIRECTORY"

echo "New Helm Charts created with app name: $app_name"