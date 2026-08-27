import pickle
import torch
import numpy as np
import yaml
from transformers import AutoModel

# AIML-001: pickle deserialization
data = pickle.load(open('data.pkl', 'rb'))

# AIML-002: torch.load without weights_only
model = torch.load('model.pt')

# AIML-003: numpy allow_pickle
arr = np.load('data.npy', allow_pickle=True)

# AIML-006: yaml.load without SafeLoader
config = yaml.load(open('config.yml'))

# AIML-014: from_pretrained
model = AutoModel.from_pretrained('some-model')

# AIML-022: hardcoded API key
OPENAI_API_KEY = "sk-proj-abcdef1234567890abcdef"
