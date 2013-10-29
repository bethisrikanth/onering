all:
	jekyll build

serve:
	jekyll serve -c _config.yml,_config.dev.yml -w
