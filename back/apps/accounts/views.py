from rest_framework import generics, permissions
from rest_framework.response import Response
from .serializers import UserSerializer, RegisterSerializer
from .models import User
from rest_framework_simplejwt.views import TokenObtainPairView

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = (permissions.AllowAny,)

class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_object(self):
        return self.request.user

class UserListView(generics.ListAPIView):
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAdminUser,)
    queryset = User.objects.all()
