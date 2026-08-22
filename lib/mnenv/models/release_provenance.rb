# frozen_string_literal: true

module Mnenv
  # Optional per-release provenance on a register entry (metanorma/ci#367).
  # Written by the rubygems-release.yml post-publish step; mnenv round-trips
  # it so daily refreshes never drop it.
  class ReleaseProvenance < Lutaml::Model::Serializable
    attribute :published_via, :string
    attribute :workflow_run_id, :integer
    attribute :workflow_url, :string
    attribute :annotation, :string

    key_value do
      map 'published_via', to: :published_via
      map 'workflow_run_id', to: :workflow_run_id
      map 'workflow_url', to: :workflow_url
      map 'annotation', to: :annotation
    end

    def to_hash
      {
        'published_via' => published_via,
        'workflow_run_id' => workflow_run_id,
        'workflow_url' => workflow_url,
        'annotation' => annotation,
      }
    end
  end
end
