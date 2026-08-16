from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status


def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is not None:
        errors = response.data
        if isinstance(errors, dict):
            detail = errors.get('detail', None)
            if detail:
                message = str(detail)
            else:
                messages = []
                for field, value in errors.items():
                    if isinstance(value, list):
                        messages.append(f"{field}: {', '.join(str(v) for v in value)}")
                    else:
                        messages.append(f"{field}: {value}")
                message = ' | '.join(messages)
        elif isinstance(errors, list):
            message = ' | '.join(str(e) for e in errors)
        else:
            message = str(errors)

        response.data = {
            'success': False,
            'message': message,
            'errors': errors,
            'status_code': response.status_code,
        }
    return response
