help()
{
    echo "Usage: $0 {web|bdd}"
    exit 1
}

get_web()
{
    web_machines=$(cat vms.csv | grep web | cut -d ',' -f 2,3 | tr ',' '@')
    echo $web_machines
}

get_bdd()
{
    bdd_machines=$(cat vms.csv | grep bdd | cut -d ',' -f 2,3 | tr ',' '@')
    echo $bdd_machines
}

if [ $# -eq 0 ]; then
    help
    exit 1
fi

case $1 in
    "web")
        get_web
        ;;
    "bdd")
        get_bdd
        ;;
    *)
        help
        ;;
esac