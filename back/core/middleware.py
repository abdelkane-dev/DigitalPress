from django.utils.deprecation import MiddlewareMixin
import logging

logger = logging.getLogger(__name__)

class RequestLoggingMiddleware(MiddlewareMixin):
    def process_request(self, request):
        logger.debug(f"Request {request.method} {request.path}")
