if ((BASH_VERSINFO[0] < 4)); then
	echo "unsupported Bash version (please use 4.0)"
	if [ "$(uname)" == "Darwin" ]; then
		echo "run the commands:"
		echo "# brew install bash"
		echo "# sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'"
		echo "# chsh -s /usr/local/bin/bash"
	fi
	exit 1
fi
if [ "$(uname)" == "Darwin" ]; then
	brew update
	brew install ucspi-tcp
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	apt-get update
	apt-get install -y ucspi-tcp
else
	echo "unsupported OS"
fi
