# Variables 
OUTPUT_DIRECTORY="output"
OUTPUT_CHARTS_FILE="$OUTPUT_DIRECTORY/Charts.yaml"
OUTPUT_VALUES_FILE="$OUTPUT_DIRECTORY/values.yaml"
HELM_TEMPLATES_DIRECTORY="template/templates"

if [ ! -d "$OUTPUT_DIRECTORY" ]; then
  mkdir -p "$OUTPUT_DIRECTORY"
fi

cp template/values.yaml.template $OUTPUT_VALUES_FILE
cp template/Charts.yaml.template $OUTPUT_CHARTS_FILE

read -p "Enter the value for application name: " app_name
sed -i.tmp "s/\${app_name}/$app_name/g" $OUTPUT_CHARTS_FILE

read -p "Enter replicas count: " replicas_count
read -p "Enter image url: " image_url
read -p "Enter port number: " port_number

sed -i.tmp \
    -e "s/\${app_name}/$app_name/g" \
    -e "s/\${replicas_count}/$replicas_count/g" \
    -e "s/\${image_url}/$image_url/g" \
    -e "s/\${port_number}/$port_number/g" \
    "$OUTPUT_VALUES_FILE"

rm -f "$OUTPUT_CHARTS_FILE.tmp" "$OUTPUT_VALUES_FILE.tmp"

cp -r "$HELM_TEMPLATES_DIRECTORY" "$OUTPUT_DIRECTORY"

echo "New Helm Charts created with app name: $app_name"