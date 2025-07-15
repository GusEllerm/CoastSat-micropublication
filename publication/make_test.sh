echo "📄 Generating DNF Document..."
stencila convert test.smd DNF_Document.json

echo "📑 Rendering DNF Document with interface.crate..."
stencila render DNF_Document.json DNF_Evaluated_Document.json --force-all --pretty 

echo "📊 Creating example presentation versions of the rendered article..."
stencila convert DNF_Evaluated_Document.json test.html --pretty 
