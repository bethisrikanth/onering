all:
	jekyll build

serve:
	jekyll serve --config _config.yml,_config.dev.yml -w

embed:
	jekyll build --config _config.yml,_config.embed.yml
