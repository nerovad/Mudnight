# Plugin system: uploaded plugins, each channel's plugin config, and each
# viewer's overrides. See docs/plugins.md.
class CreatePlugins < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TABLE public.plugins (
          id bigserial PRIMARY KEY,
          plugin_key text NOT NULL UNIQUE,
          author_id integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
          manifest jsonb NOT NULL,
          code text NOT NULL,
          visibility text DEFAULT 'unlisted'::text NOT NULL,
          created_at timestamp with time zone DEFAULT now() NOT NULL,
          updated_at timestamp with time zone DEFAULT now() NOT NULL,
          CONSTRAINT plugins_visibility_check CHECK ((visibility = ANY (ARRAY['unlisted'::text, 'public'::text])))
      );

      CREATE INDEX plugins_author_id_idx ON public.plugins (author_id);

      CREATE TABLE public.user_plugin_prefs (
          user_id integer PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
          prefs jsonb DEFAULT '{}'::jsonb NOT NULL,
          updated_at timestamp with time zone DEFAULT now() NOT NULL
      );

      ALTER TABLE public.channels ADD COLUMN plugins jsonb DEFAULT '[]'::jsonb NOT NULL;
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE public.channels DROP COLUMN plugins;
      DROP TABLE public.user_plugin_prefs;
      DROP TABLE public.plugins;
    SQL
  end
end
