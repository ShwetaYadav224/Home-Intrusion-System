"""
ArcFace face-embedding client.

Uses InsightFace's Buffalo_L model to extract 512-dim normalized
embeddings from face images, and provides cosine-similarity comparison.
"""

import logging

import cv2
import numpy as np
from insightface.app import FaceAnalysis

logger = logging.getLogger(__name__)

_app = None
_app_initialized = False

def get_app():
    global _app, _app_initialized
    if not _app_initialized:
        try:
            from insightface.app import FaceAnalysis
            _app = FaceAnalysis(
                name="buffalo_l",
                providers=["CUDAExecutionProvider", "CPUExecutionProvider"],
            )
            _app.prepare(ctx_id=0, det_size=(640, 640))
            logger.info("ArcFace model (buffalo_l) loaded successfully.")
        except Exception as e:
            logger.error("Failed to initialize ArcFace model: %s", e)
            _app = None
        _app_initialized = True
    return _app

def get_face_embedding(image_bytes: bytes) -> tuple[list[float] | None, str]:
    """
    Extract the ArcFace embedding from the largest face in an image.

    Args:
        image_bytes: Raw JPEG/PNG image data.

    Returns:
        (embedding_list, message)
        embedding_list is ``None`` when no face could be processed.
    """
    app = get_app()
    if app is None:
        return None, "ArcFace model is not initialized."

    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        return None, "Failed to decode image bytes."

    try:
        faces = app.get(img)
    except Exception as e:
        logger.error("Error during face detection: %s", e)
        return None, f"Error during face detection: {e}"

    if not faces:
        return None, "No face detected in the image."

    faces.sort(
        key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]),
        reverse=True,
    )
    face = faces[0]

    if face.normed_embedding is None:
        return None, "Face detected but no embedding found (check model type)."

    return face.normed_embedding.tolist(), "Face detected and embedding extracted."


def compute_similarity(embedding_a: list[float], embedding_b: list[float]) -> float:
    """
    Compute cosine similarity between two 512-dim embeddings.

    Returns:
        Float in [-1.0, 1.0]. Higher means more similar.
    """
    if not embedding_a or not embedding_b:
        return 0.0

    a = np.array(embedding_a)
    b = np.array(embedding_b)

    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)

    if norm_a == 0 or norm_b == 0:
        return 0.0

    return float(np.dot(a, b) / (norm_a * norm_b))
