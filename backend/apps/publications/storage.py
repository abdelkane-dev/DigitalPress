"""
Supabase Storage Backend pour Django.

Remplace le système de fichiers local éphémère de Render par un stockage
cloud persistant via l'API REST Supabase Storage.

Aucune dépendance supplémentaire requise : utilise requests, déjà présent.

Variables d'environnement attendues :
  SUPABASE_URL    → URL du projet Supabase (ex: https://xxxx.supabase.co)
  SUPABASE_KEY    → Clé service_role (depuis Settings > API > service_role)
  SUPABASE_BUCKET → Nom du bucket public (ex: digitalpress-media)
"""
import requests
from django.core.files.base import ContentFile
from django.core.files.storage import Storage
from django.conf import settings


class SupabaseStorage(Storage):
    """Backend de stockage Supabase persistant."""

    def __init__(self):
        self._base_url = getattr(settings, 'SUPABASE_URL', '').rstrip('/')
        self._key = getattr(settings, 'SUPABASE_KEY', '')
        self._bucket = getattr(settings, 'SUPABASE_BUCKET', 'digitalpress-media')

    @property
    def _headers(self):
        return {
            'Authorization': f'Bearer {self._key}',
            'apikey': self._key,
        }

    # ─────────────────────────────────────────────────────────
    # Méthodes obligatoires
    # ─────────────────────────────────────────────────────────

    def _save(self, name, content):
        """Upload le fichier dans le bucket Supabase (upsert activé)."""
        data = content.read()
        content_type = (
            getattr(content, 'content_type', None)
            or 'application/octet-stream'
        )
        resp = requests.post(
            f"{self._base_url}/storage/v1/object/{self._bucket}/{name}",
            headers={
                **self._headers,
                'Content-Type': content_type,
                'x-upsert': 'true',  # Écrase si le fichier existe déjà
            },
            data=data,
            timeout=120,
        )
        resp.raise_for_status()
        return name

    def _open(self, name, mode='rb'):
        """Télécharge un fichier depuis Supabase (lecture seule)."""
        resp = requests.get(
            f"{self._base_url}/storage/v1/object/{self._bucket}/{name}",
            headers=self._headers,
            timeout=30,
        )
        resp.raise_for_status()
        return ContentFile(resp.content)

    def exists(self, name):
        """
        Retourne toujours False : on laisse Supabase gérer les doublons
        via x-upsert. Cela évite une requête supplémentaire pour chaque upload.
        """
        return False

    def url(self, name):
        """Retourne l'URL publique permanente du fichier."""
        return f"{self._base_url}/storage/v1/object/public/{self._bucket}/{name}"

    # ─────────────────────────────────────────────────────────
    # Méthodes optionnelles
    # ─────────────────────────────────────────────────────────

    def delete(self, name):
        """Supprime un fichier du bucket Supabase."""
        try:
            requests.delete(
                f"{self._base_url}/storage/v1/object/{self._bucket}",
                headers={**self._headers, 'Content-Type': 'application/json'},
                json={'prefixes': [name]},
                timeout=10,
            )
        except Exception:
            pass  # La suppression non-critique ne doit pas faire planter l'app

    def size(self, name):
        return 0

    def get_available_name(self, name, max_length=None):
        """Upsert géré côté Supabase : pas de suffixe numérique à ajouter."""
        return name
