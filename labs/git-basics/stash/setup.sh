git init -b main -q proj
cd proj
echo "# Shopping App" > app.py
echo "print('App running')" >> app.py
git add app.py
git commit -q -m "Initial commit on main"

git switch -q -c feature
echo "print('WIP feature: shopping cart')" >> app.py
git commit -q -am "Start shopping cart feature"
echo "print('uncommitted work in progress')" >> app.py
