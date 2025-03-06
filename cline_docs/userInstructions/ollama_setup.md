# Setting up Ollama Backend

## Installation

1. Download and install Ollama from [ollama.ai/download](https://ollama.ai/download)
2. After installation, Ollama will run as a local service on port 11434

## Configuration in ButlerAI

1. Open ButlerAI settings:
   - Click the wand icon (✨) in your menubar
   - Select "Settings..."

2. Switch to Ollama backend:
   - In the settings window, select "Ollama (Local)"
   - The app will automatically try to connect to Ollama and fetch available models

3. Configure Ollama settings:
   - Server URL: Default is `http://localhost:11434` (change only if running Ollama on a different machine)
   - Select your preferred model from the dropdown
   - If no models are shown, click "Refresh Models"

## Managing Ollama Models

1. Pull models using Ollama CLI:
   ```bash
   ollama pull llama2    # Pull Llama 2
   ollama pull mistral   # Pull Mistral
   ollama pull vicuna    # Pull Vicuna
   ```

2. List available models:
   ```bash
   ollama list
   ```

3. Remove models:
   ```bash
   ollama rm model-name
   ```

## Troubleshooting

1. If models don't appear:
   - Ensure Ollama is running (`ps aux | grep ollama`)
   - Check the server URL in settings
   - Click "Refresh Models" button
   - Try restarting Ollama service

2. If connection fails:
   - Verify Ollama is installed and running
   - Ensure port 11434 is not blocked
   - Check system firewall settings

3. Common errors:
   - "Connection refused": Ollama service is not running
   - "No models available": Need to pull models first using Ollama CLI
   - "Model not found": Selected model needs to be pulled

## Advanced Configuration

1. Running Ollama on a different machine:
   - Install Ollama on the remote machine
   - Configure network access and firewalls
   - Update server URL in ButlerAI settings with the remote machine's IP

2. Custom model configuration:
   - Follow Ollama documentation for custom model setup
   - Models will appear in ButlerAI's model selection once pulled

## Additional Resources

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Available Models](https://ollama.ai/library)
- [OpenAI Compatibility](https://ollama.com/blog/openai-compatibility)
