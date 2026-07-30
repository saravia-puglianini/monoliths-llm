#!/bin/dash
[ ! -d ~/piper ] && mkdir -p ~/piper
[ -d ~/piper ] && tar -xzf ~/monoliths-llm/piper.tar.gz -C ~/piper
echo "Willkomen zum Piper" | $HOME/piper/piper --model $HOME/piper/de_DE-thorsten-high.onnx --output_file "/tmp/de_DE-thorsten-high.onnx.wav"
echo "Bienvenido a piper" | $HOME/piper/piper --model $HOME/piper/es_MX-claude-high.onnx --output_file "/tmp/es_MX-claude-high.onnx.wav"