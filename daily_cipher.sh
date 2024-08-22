#!/bin/bash

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
rest='\033[0m'

# Install jq
if ! command -v jq &>/dev/null; then
	# Check if the environment is Termux
	if [ -n "$TERMUX_VERSION" ]; then
		pkg update -y
		pkg install -y jq
	else
		apt update -y && apt install -y jq
	fi
fi

if ! command -v curl &>/dev/null; then
	# Check if the environment is Termux
	if [ -n "$TERMUX_VERSION" ]; then
		pkg install curl -y
	else
		apt update -y && apt install curl -y
	fi
fi

# Clear the screen
clear
echo -e "${purple}=======${yellow} Hamster Combat Daily Cypher${purple}=======${rest}"
echo ""
echo -en "${green}Enter Authorization [${cyan}Example: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization

# Function to convert text to Morse code
text_to_morse() {
	local text="$1"
	declare -A morse_code_map=(
		[A]=".-" [B]="-..." [C]="-.-." [D]="-.." [E]="." [F]="..-."
		[G]="--." [H]="...." [I]=".." [J]=".---" [K]="-.-" [L]=".-.."
		[M]="--" [N]="-." [O]="---" [P]=".--." [Q]="--.-" [R]=".-."
		[S]="..." [T]="-" [U]="..-" [V]="...-" [W]=".--" [X]="-..-"
		[Y]="-.--" [Z]="--.." [0]="-----" [1]=".----" [2]="..---" [3]="...--"
		[4]="....-" [5]="....." [6]="-...." [7]="--..." [8]="---.." [9]="----."
	)

	local morse=""
	local char
	for ((i = 0; i < ${#text}; i++)); do
		char="${text:$i:1}"
		morse+="${morse_code_map[$char]} "
	done

	echo "$morse"
}

# Function to fetch available taps
get_available_taps() {
	curl -s -X POST https://api.hamsterkombatgame.io/clicker/sync \
		-H "Content-Type: application/json" \
		-H "Authorization: $Authorization" \
		-d '{}' | jq -r '.clickerUser.availableTaps'
}

# Function to send tap request with a specific symbol
send_tap_request() {
	local symbol="$1"
	local count
	case "$symbol" in
	"-")
		count=1
		;;
	".")
		count=0
		;;
	*)
		echo -e "${red}Invalid symbol for tap request: $symbol${rest}"
		return
		;;
	esac
	curl -s -X POST https://api.hamsterkombatgame.io/clicker/tap \
		-H "Authorization: $Authorization" \
		-H "Content-Type: application/json" \
		-H "Accept: application/json" \
		-d "{\"count\": $count, \"timestamp\": $(date +%s)}" >/dev/null
}

# Function to execute taps based on Morse code
execute_taps() {
	local morse_code="$1"
	local symbol
	local morse_output=""

	echo -e "${purple}Morse Code: ${green}$morse_code${rest}"
	echo -e "${purple}-----------${green}Please Wait${purple}-----------${rest}"

	for ((i = 0; i < ${#morse_code}; i++)); do
		symbol="${morse_code:$i:1}"

		case "$symbol" in
		"-")
			morse_output+="_"
			send_tap_request "-"
			;;
		".")
			morse_output+="."
			send_tap_request "."
			;;
		" " | "/")
			morse_output+=" "
			sleep 1
			continue
			;;
		*)
			echo -e "${red}Unknown symbol detected: $symbol${rest}"
			continue
			;;
		esac

		# Small delay between taps
		sleep 0.5
	done
}

# Function to claim the daily cipher
claim_cipher() {
	local cipher="$1"

	response=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/claim-daily-cipher \
		-H "Authorization: $Authorization" \
		-H "Content-Type: application/json" \
		-d "{\"cipher\": \"$cipher\"}")

	if [ "$(echo "$response" | jq -r '.dailyCipher.isClaimed')" == "true" ]; then
		claimed_at=$(echo "$response" | jq -r '.clickerUser.claimedCipherAt')
		echo -e "${green}Daily cipher successfully claimed at ${claimed_at}.${rest}"
	else
		echo -e "${red}Failed to claim the daily cipher.${rest}"
	fi
}

# Function to check if the cipher has been claimed
check_cipher_claim_status() {
	response=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/config \
		-H "Content-Type: application/json" \
		-H "Authorization: $Authorization" \
		-d '{}')

	echo "$response" | jq -r '.dailyCipher.isClaimed'
}

# Main script logic
while true; do
	available_taps=$(get_available_taps)

	# Wait until we have at least 500 taps
	while [ "$available_taps" -lt 500 ]; do
		echo -e "${purple}---------------------------------${rest}"
		echo -e "${yellow}Not enough taps. Waiting ${green}120 seconds${yellow} for more...${rest}"
		echo -e "${purple}---------------------------------${rest}"
		sleep 120
		available_taps=$(get_available_taps)
	done

	# Fetch and decode the cipher
	cipher=$(curl -s -X POST https://api.hamsterkombatgame.io/clicker/config \
		-H "Accept: application/json" \
		-H "Authorization: $Authorization" \
		-H "Content-Type: application/json" \
		-d '{}' | jq -r '.dailyCipher.cipher')

	if [ -z "$cipher" ]; then
		echo -e "${red}Error: No cipher received.${rest}"
		exit 1
	fi

	modified_cipher="${cipher:0:3}${cipher:4}"
	decoded_cipher=$(echo "$modified_cipher" | base64 --decode)

	echo -e "${purple}---------------------------------${rest}"
	echo -e "${green}Daily Cipher is: ${cyan}$decoded_cipher${rest}"
	echo -e "${purple}---------------------------------${rest}"

	morse_code=$(text_to_morse "$decoded_cipher")

	is_claimed=$(check_cipher_claim_status)

	if [ "$is_claimed" = "true" ]; then
		echo -e "${green}Daily cipher is already claimed.${rest}"
		echo -e "${purple}---------------------------------${rest}"
		exit 0
	else
		echo -e "${cyan}Daily cipher not claimed. ${yellow}Proceeding...${rest}"
	fi

	execute_taps "$morse_code"
	claim_cipher "$decoded_cipher"

	is_claimed=$(check_cipher_claim_status)

	if [ "$is_claimed" = "true" ]; then
		echo -e "${purple}---------------------------------${rest}"
		echo -e "${green}Cipher claimed successfully.${rest}"
		echo -e "${purple}---------------------------------${rest}"
		exit 0
	else
		echo -e "${yellow}Retrying to claim...${rest}"
		echo -e "${purple}---------------------------------${rest}"
	fi

	sleep 10
done
