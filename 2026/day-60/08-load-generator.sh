#!/bin/bash

echo "🔥 Starting Load Generator against WordPress..."
echo "This will spam the frontend with requests to spike the CPU."
echo "Press Ctrl+C to stop."
echo ""

# Infinite loop hitting the WordPress NodePort
while true; do
  # -s hides the progress bar, -o /dev/null throws away the HTML response
  curl -s -o /dev/null http://localhost:30080
  
  # Print a dot to show it's working
  echo -n "🔥"
  
  # A tiny sleep to prevent the script from crashing your terminal, 
  # but fast enough to cause a massive CPU spike!
  sleep 0.05
done
