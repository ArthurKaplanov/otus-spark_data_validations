install:
	uv sync

pre-commit
	uv run pre-commit install

test:
	uv run pytest

lint:
	uv run ruff check src tests

format:
	uv run black src tests

train:
	uv run python -m hw2_spark_data_validation.models.train_model

predict:
	uv run python -m hw2_spark_data_validation.models.predict_model

notebook:
	uv run jupyter notebook