# -*- coding: utf-8 -*-
#
from django.contrib.auth import logout as django_logout
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from common.utils import get_logger

logger = get_logger(__name__)

__all__ = ['LogoutApi']


class LogoutApi(APIView):
    """
    Logout API for admin password-based authentication

    Clears Django session and returns success response
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        """
        POST /api/v1/authentication/logout/

        Logs out the current user by clearing their Django session
        """
        user = request.user
        logger.info(f"User {user.username} logging out via API")

        # Clear Django session
        django_logout(request)

        return Response({
            'msg': 'Logged out successfully',
            'detail': 'Session cleared'
        }, status=200)
