
echo "Pushing the fixilya repo ..." 
current_datetime=$(date "+%B %d, %Y %I:%M %p")
git add .
git commit -m "working on ... | $current_datetime |"
git push -u origine master

echo "Repo is pushed ..." 

echo "Done !"