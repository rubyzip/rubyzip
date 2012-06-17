for i in ree 1.8.7 1.9.2 1.9.3; do
  git clean -nfx
  rvm $i do rake
done
