from rest_framework import serializers
from .models import Publication

class PublicationSerializer(serializers.ModelSerializer):
    publisher_name = serializers.CharField(source='publisher.username', read_only=True)
    class Meta:
        model = Publication
        fields = ('id','title','description','publisher','publisher_name','created_at')
