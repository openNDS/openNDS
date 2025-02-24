# query_string="?fas=aGlkPTgzNTljMjFjZWVlYTBhOGFiYzBhZTQxNWY0MDQ4YmZhY2ZkNWJmNzA1ZTZlNzNkZjA2NTRhNjgxY2Q2OGY4ZWUsIGNsaWVudGlwPTEwLjAuMS4yMjEsIGNsaWVudG1hYz00MDplYzo5OTo1Mzo3ZDo3MCwgY2xpZW50X3R5cGU9Y3BkX2NhbiwgY3BpX3F1ZXJ5PSwgZ2F0ZXdheW5hbWU9b3Blbk5EUyUyME5vZGUlM2FiYTI3ZWIwYWY0ZTUlMjAsIGdhdGV3YXl1cmw9aHR0cCUzYSUyZiUyZnN0YXR1cy5jbGllbnQsIHZlcnNpb249MTAuMy4wLCBnYXRld2F5YWRkcmVzcz0xMC4wLjEuMToyMDUwLCBnYXRld2F5bWFjPWJhMjdlYjBhZjRlNSwgb3JpZ2ludXJsPWh0dHAlM2ElMmYlMmZ3d3cubXNmdGNvbm5lY3R0ZXN0LmNvbSUyZnJlZGlyZWN0LCBjbGllbnRpZj1waHkwLWFwMCwgdGhlbWVzcGVjPS91c3IvbGliL29wZW5uZHMvdGhlbWVfdm91Y2hlci5zaCwgKG51bGwpKG51bGwpKG51bGwpKG51bGwp, complete=true, voucher=(207) 440 - 8296, email=jacob@gofocus.space, zipcode=234324, tos=accepted"
query_string="?fas=aGlkPTgzNTljMjFjZWVlYTBhOGFiYzBhZTQxNWY0MDQ4YmZhY2ZkNWJmNzA1ZTZlNzNkZjA2NTRhNjgxY2Q2OGY4ZWUsIGNsaWVudGlwPTEwLjAuMS4yMjEsIGNsaWVudG1hYz00MDplYzo5OTo1Mzo3ZDo3MCwgY2xpZW50X3R5cGU9Y3BkX2NhbiwgY3BpX3F1ZXJ5PSwgZ2F0ZXdheW5hbWU9b3Blbk5EUyUyME5vZGUlM2FiYTI3ZWIwYWY0ZTUlMjAsIGdhdGV3YXl1cmw9aHR0cCUzYSUyZiUyZnN0YXR1cy5jbGllbnQsIHZlcnNpb249MTAuMy4wLCBnYXRld2F5YWRkcmVzcz0xMC4wLjEuMToyMDUwLCBnYXRld2F5bWFjPWJhMjdlYjBhZjRlNSwgb3JpZ2ludXJsPWh0dHAlM2ElMmYlMmZ3d3cubXNmdGNvbm5lY3R0ZXN0LmNvbSUyZnJlZGlyZWN0LCBjbGllbnRpZj1waHkwLWFwMCwgdGhlbWVzcGVjPS91c3IvbGliL29wZW5uZHMvdGhlbWVfdm91Y2hlci5zaCwgKG51bGwpKG51bGwpKG51bGwpKG51bGwp"

# Remove the leading '?' if present
query_string="${query_string#\?}"

# Remove 'fas' and 'tos' from query string
cleaned_query=$(echo "$query_string" | sed -E 's/(fas=[^,]*, |tos=[^,]*, )//g')


test_query="fas=fsdkljfiaoji8227238,complete=true,voucher=(207) 440 - 8296,email=jacob@gofocus.space,zipcode=23423,tos=accepted"

# Parse and export variables
echo "$test_query" | IFS=', ' read -r -a params

# Iterate through the parameters
IFS=',' 
for param in $test_query; do
    key=$(echo "$param" | cut -d= -f1)
    value=$(echo "$param" | cut -d= -f2-)

    # Export key-value pair
    export "$key=$value"

    # Debugging output
    echo "$key=$value"
done

# Debug output (optional)
echo "Cleaned Query: $test_query"
echo "Email: $email"
echo "Zipcode: $zipcode"
echo "Voucher: $voucher"
echo "Continue: $continue"

# # Remove the leading "?" if present
# # function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }
# cleaned_query=$(echo "$query_string" | sed -E 's/(fas=[^,]*, |tos=[^,]*, )//g')
# echo $decoded_query

# # Parse and bind variables dynamically
# # while IFS='=' read -r key value; do
# #     declare "$key=$value"
# # done < <(echo "$decoded_query" | tr '&' '\n')

# # Build the environment variable string dynamically
# while IFS='=' read -r key value; do
#     export "$key=$value"
# done < <(echo "$cleaned_query" | tr ', ' '\n')

# # Output the variables
# # echo "env_vars $env_vars"
# echo "Email=$email"

# # eval "env $env_vars cowsay 'moo'"