from rest_framework import serializers
from .models import User, PublisherProfile

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id','username','email','name','role')

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    class Meta:
        model = User
        fields = ('username','email','password','name','role')

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        if user.role == 'publisher':
            PublisherProfile.objects.create(user=user, company_name='')
        return user
