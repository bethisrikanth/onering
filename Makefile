all:
	jekyll build

serve:
	jekyll serve --config _config.yml,_config.dev.yml -w
