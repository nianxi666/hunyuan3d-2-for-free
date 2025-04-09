#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
CONDA_ENV_NAME="hunyuan3d_env"
PYTHON_VERSION="3.10"
PROJECT_DIR="/workspace/Hunyuan3D-2GP"
PROJECT_REPO="https://openi.pcl.ac.cn/NewestAI/Hunyuan3D-2GP.git"
WORKSPACE_DIR="/workspace"

# U2Net configuration (keeping original paths for consistency, ensure permissions)
U2NET_DIR="/root/.u2net"
U2NET_FILE="$U2NET_DIR/u2net.onnx"
U2NET_URL="https://hf-mirror.com/tomjackson2023/rembg/resolve/main/u2net.onnx"

# PyTorch installation URL
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu118"

# Hugging Face Mirror Endpoint
export HF_ENDPOINT="https://hf-mirror.com"

echo "--- Script Start ---"
echo "Project Directory: $PROJECT_DIR"
echo "Conda Environment: $CONDA_ENV_NAME (Python $PYTHON_VERSION)"
echo "Using HF Endpoint: $HF_ENDPOINT"

# --- Check for Conda ---
if ! command -v conda &> /dev/null; then
    echo "Error: conda command not found. Please ensure Anaconda or Miniconda is installed and configured."
    exit 1
fi

# --- Setup Conda Environment ---
echo "Checking for Conda environment '$CONDA_ENV_NAME'..."
# Check if the environment already exists
if conda env list | grep -q "^${CONDA_ENV_NAME}\s"; then
    echo "Conda environment '$CONDA_ENV_NAME' already exists."
else
    echo "Creating Conda environment '$CONDA_ENV_NAME' with Python $PYTHON_VERSION..."
    conda create -n "$CONDA_ENV_NAME" python="$PYTHON_VERSION" -y || { echo "Failed to create conda environment."; exit 1; }
    echo "Conda environment created successfully."
fi

echo "Activating Conda environment '$CONDA_ENV_NAME'..."
# Activate the environment. Use conda run for non-interactive or source for interactive-like behavior
# Using 'source activate' style might not work reliably in non-interactive scripts depending on conda version/setup.
# A more robust way is often to use `conda run -n <env_name> <command>` or ensure bash profile sources conda init.
# For simplicity here, we'll try `source activate` assuming `conda init` has been run previously.
# If this fails, consider prefixing commands with `conda run -n $CONDA_ENV_NAME ...`
eval "$(conda shell.bash hook)" # Ensure conda commands work in script
conda activate "$CONDA_ENV_NAME" || { echo "Failed to activate conda environment '$CONDA_ENV_NAME'."; exit 1; }
echo "Conda environment activated."

# --- Setup Project Repository ---
echo "Checking for project directory '$PROJECT_DIR'..."
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory not found. Cloning repository..."
    # Ensure workspace directory exists
    mkdir -p "$WORKSPACE_DIR" || { echo "Failed to create workspace directory $WORKSPACE_DIR"; exit 1; }
    cd "$WORKSPACE_DIR" || { echo "Failed to change directory to $WORKSPACE_DIR"; exit 1; }
    git clone "$PROJECT_REPO" "$PROJECT_DIR" || { echo "Failed to clone repository $PROJECT_REPO"; exit 1; }
    echo "Repository cloned successfully to $PROJECT_DIR."
else
    echo "Project directory '$PROJECT_DIR' already exists. Skipping clone."
fi

# Navigate into the project directory
cd "$PROJECT_DIR" || { echo "Failed to change directory to $PROJECT_DIR"; exit 1; }
echo "Changed directory to $PROJECT_DIR."

# --- Download u2net Model ---
echo "Checking for u2net model ($U2NET_FILE)..."
if [ ! -f "$U2NET_FILE" ]; then
    echo "Model file $U2NET_FILE does not exist. Creating directory and downloading..."
    mkdir -p "$U2NET_DIR" || { echo "Failed to create directory $U2NET_DIR"; exit 1; }
    # Use curl for potentially better redirect handling and progress, but wget is fine too
    # curl -L "$U2NET_URL" -o "$U2NET_FILE" || { echo "Failed to download u2net.onnx model from $U2NET_URL"; exit 1; }
    wget --trust-server-names -L "$U2NET_URL" -O "$U2NET_FILE" || { echo "Failed to download u2net.onnx model from $U2NET_URL"; exit 1; }
    echo "u2net.onnx model downloaded successfully."
else
    echo "u2net.onnx model file $U2NET_FILE already exists. Skipping download."
fi

# --- Install Dependencies ---
# Note: We are already inside the activated conda environment

echo "Installing PyTorch, torchvision, torchaudio..."
pip install torch torchvision torchaudio --index-url "$PYTORCH_INDEX_URL" || { echo "Failed to install PyTorch."; exit 1; }
echo "PyTorch installation complete."

echo "Installing dependencies from requirements.txt..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt || { echo "Failed to install requirements from requirements.txt"; exit 1; }
    echo "Dependencies from requirements.txt installed successfully."
else
    echo "Warning: requirements.txt not found in $PROJECT_DIR. Skipping dependency installation."
fi

echo "Installing custom_rasterizer..."
# Ensure we are in the correct subdirectory relative to $PROJECT_DIR
if [ -d "hy3dgen/texgen/custom_rasterizer" ]; then
    cd hy3dgen/texgen/custom_rasterizer || { echo "Failed to enter custom_rasterizer directory"; exit 1; }
    python setup.py install || { echo "Failed to install custom_rasterizer"; exit 1; }
    cd "$PROJECT_DIR" # Go back to project root
    echo "custom_rasterizer installed successfully."
else
    echo "Error: custom_rasterizer directory not found at hy3dgen/texgen/custom_rasterizer"; exit 1;
fi

echo "Installing differentiable_renderer..."
# Ensure we are in the correct subdirectory relative to $PROJECT_DIR
if [ -d "hy3dgen/texgen/differentiable_renderer" ]; then
    cd hy3dgen/texgen/differentiable_renderer || { echo "Failed to enter differentiable_renderer directory"; exit 1; }
    python setup.py install || { echo "Failed to install differentiable_renderer"; exit 1; }
    cd "$PROJECT_DIR" # Go back to project root
    echo "differentiable_renderer installed successfully."
else
     echo "Error: differentiable_renderer directory not found at hy3dgen/texgen/differentiable_renderer"; exit 1;
fi

# --- Execute Application ---
echo "Starting the application (gradio_app.py)..."
# Ensure Hugging Face endpoint is set for this execution context (already done globally)
# export HF_ENDPOINT="https://hf-mirror.com"
python gradio_app.py --enable_t23d

echo "--- Script End ---"

# Deactivate conda environment (optional, script end will handle it)
# conda deactivate
