# FastAPI backend
from fastapi import FastAPI
from pydantic import BaseModel
from ai_engine import generate_response

app = FastAPI()

class Query(BaseModel):    prompt: str

@app.post("/ask")
async def ask(query: Query):
    try:
        response = generate_response(query.prompt)
        return {"response": response}
    except Exception as e:
        return {"error": str(e)}
