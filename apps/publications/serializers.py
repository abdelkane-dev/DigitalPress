from rest_framework import serializers
from .models import Publication, PublicationContent

class PublicationContentSerializer(serializers.ModelSerializer):
    class Meta:
        model = PublicationContent
        fields = ['file', 'encrypted']

class PublicationSerializer(serializers.ModelSerializer):
    # On inclut le contenu de manière imbriquée
    content = PublicationContentSerializer(required=False)
    editor_name = serializers.ReadOnlyField(source='editor.company_name')

    class Meta:
        model = Publication
        fields = [
            'id', 'editor', 'editor_name', 'title', 'category', 
            'publication_date', 'price', 'format', 'status', 'content'
        ]
        read_only_fields = ['editor']

    def create(self, validated_data):
        # Logique pour créer la publication et son contenu simultanément [cite: 62]
        content_data = self.context['request'].FILES.get('file')
        publication = Publication.objects.create(**validated_data)
        if content_data:
            PublicationContent.objects.create(publication=publication, file=content_data)
        return publication