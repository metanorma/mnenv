# frozen_string_literal: true

RSpec.describe Mnenv::ArtifactVersion do
  describe '#initialize' do
    it 'creates a version with number' do
      version = Mnenv::ArtifactVersion.new(version: '1.2.3')
      expect(version.version).to eq('1.2.3')
    end

    it 'creates a version with timestamps' do
      published_at = DateTime.now
      parsed_at = DateTime.now

      version = Mnenv::ArtifactVersion.new(
        version: '1.2.3',
        published_at: published_at,
        parsed_at: parsed_at
      )

      expect(version.published_at).to be_a(DateTime)
      expect(version.parsed_at).to be_a(DateTime)
    end
  end

  describe '#display_name' do
    it 'returns version with v prefix' do
      version = Mnenv::ArtifactVersion.new(version: '1.2.3')
      expect(version.display_name).to eq('v1.2.3')
    end
  end

  describe '#<=>' do
    it 'compares versions correctly' do
      v1 = Mnenv::ArtifactVersion.new(version: '1.2.3')
      v2 = Mnenv::ArtifactVersion.new(version: '1.2.4')
      v3 = Mnenv::ArtifactVersion.new(version: '1.2.3')

      expect(v1 <=> v2).to be(-1)
      expect(v2 <=> v1).to be(1)
      expect(v1 <=> v3).to be(0)
    end
  end
end
