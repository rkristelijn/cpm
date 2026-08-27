# AI/ML Security Rules (AIML-001 – AIML-025)

cpm detects insecure patterns in machine learning pipelines: unsafe deserialization, unverified model loading, supply chain risks, and hardcoded ML service credentials. These rules target Python files and Jupyter notebooks where ML code typically lives.

## Rules

### Deserialization & Code Execution (001–010)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| AIML-001 | Unsafe pickle deserialization | error | pattern |
| AIML-002 | torch.load without weights_only | error | pattern |
| AIML-003 | numpy.load with allow_pickle | error | pattern |
| AIML-004 | Unsafe joblib deserialization | error | pattern |
| AIML-005 | Unsafe pandas pickle deserialization | error | pattern |
| AIML-006 | yaml.load without SafeLoader | error | pattern |
| AIML-007 | Unsafe shelve deserialization | error | pattern |
| AIML-008 | Unsafe dill deserialization | error | pattern |
| AIML-009 | Unsafe cloudpickle deserialization | error | pattern |
| AIML-010 | Unsafe marshal deserialization | error | pattern |

### ML Framework Specific (011–018)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| AIML-011 | TensorFlow SavedModel arbitrary code risk | error | pattern |
| AIML-012 | Keras load_model arbitrary code via Lambda | error | pattern |
| AIML-013 | ONNX model custom operator risk | warning | pattern |
| AIML-014 | HuggingFace from_pretrained supply chain risk | warning | pattern |
| AIML-015 | LangChain agent arbitrary code execution | warning | pattern |
| AIML-016 | eval/exec in ML pipeline | error | pattern |
| AIML-017 | subprocess shell injection in ML pipeline | error | pattern |
| AIML-018 | Remote artifact loading from wandb/mlflow | info | pattern |

### Data & Model Supply Chain (019–025)

| ID | Title | Severity | Engine |
|----|-------|----------|--------|
| AIML-019 | HuggingFace Hub model download | warning | pattern |
| AIML-020 | pip install in notebook or script | warning | pattern |
| AIML-021 | ML inference endpoint without input validation | warning | pattern |
| AIML-022 | Hardcoded ML service API key | error | pattern |
| AIML-023 | torch.hub.load remote code execution | warning | pattern |
| AIML-024 | Loading pickle-based model files | error | pattern |
| AIML-025 | Gradio/Streamlit app without authentication | warning | presence |

## Fix guidance

### Deserialization (AIML-001–010)

The #1 ML security risk. Pickle, torch, joblib, and similar formats execute arbitrary code on load.

```python
# Bad — arbitrary code execution
model = pickle.load(open('model.pkl', 'rb'))
model = torch.load('model.pt')
data = np.load('data.npy', allow_pickle=True)

# Good — safe alternatives
model = torch.load('model.pt', weights_only=True)
data = np.load('data.npy')  # allow_pickle defaults to False
config = yaml.safe_load(open('config.yml'))

# Best — use safe formats
model.load_state_dict(torch.load('weights.pt', weights_only=True))
data = np.loadtxt('data.csv')  # text format, no code execution
```

### Supply chain (AIML-014, 019, 023)

Models from public hubs can contain malicious code.

```python
# Risky — loads arbitrary code from HuggingFace
model = AutoModel.from_pretrained('random-user/model')

# Better — pin revision + verify
model = AutoModel.from_pretrained(
    'org/model',
    revision='abc123',  # pin to known-good commit
    trust_remote_code=False  # default, but be explicit
)
```

### API keys (AIML-022)

```python
# Bad
OPENAI_API_KEY = "sk-proj-abc123"

# Good
import os
OPENAI_API_KEY = os.environ["OPENAI_API_KEY"]
```

## Configuration

```toml
# cpm.toml — adjust for your ML project
[skip]
rules = ["AIML-018"]  # wandb artifact loading is expected

# Target files: .py, .ipynb, .pynb
# Excluded: node_modules/, vendor/, .git/, venv/, __pycache__/
```

## References

- @see rules/ai-ml/ — all 25 rule files
- @see https://blog.trailofbits.com/2021/03/15/never-a-dill-moment/ — pickle risks
- @see https://pytorch.org/docs/stable/generated/torch.load.html — weights_only parameter
