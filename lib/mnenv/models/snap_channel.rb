# frozen_string_literal: true

module Mnenv
  class SnapChannel < Lutaml::Model::Serializable
    attribute :revision, :integer
    attribute :arch, :string, default: 'amd64'
    attribute :name, :string, default: 'stable'

    key_value do
      map 'name', to: :name
      map 'revision', to: :revision
      map 'arch', to: :arch
    end

    def to_hash
      super.merge(
        'revision' => revision,
        'arch' => arch,
        'name' => name
      )
    end
  end
end
