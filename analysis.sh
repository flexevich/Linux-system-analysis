#!/bin/bash

# ------------------------------------------------------------
# -- Setup parameters
# ------------------------------------------------------------

set +e #выполнение даже с ошибками

# Цветной вывод на консоли
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m'

# Фиксируем текущую дату
start=$(date +%s)

#Дата и время для поиска изменённых за это время файлов для поиска в домашних каталогах)
startdate="2024-05-01 00:53:00"
enddate="2024-05-15 05:00:00" 

# Проверка, что мы root
echo "Текущий пользователь:"
echo $(id -u -n)

# «Без root будет бедная форензика»
if (( $EUID != 0 )); then
    echo -e "${red}Пользователь не root${clear}"
fi

# Создаем директорию для сохранения результатов (если не указан аргумент скрипта)
if [ -z $1 ]; then
    part1=$(hostname) # Имя хоста
    echo "Текущий хост: $part1"
    time_stamp=$(date +%Y-%m-%d-%H.%M.%S) # Берем дату и время
    curruser=$(whoami) # Текущий юзер
    OUTDIR="./${part1}_${curruser}_$time_stamp" # Имя директории
else
   OUTDIR=$1
fi

# Создаем директорию и переходим в нее
mkdir -pv $OUTDIR
cd $OUTDIR

# Создаем вложенную директорию для триажа
mkdir -p ./artifacts


#Поиск IP-адресов, ищем в логах приложений /usr /etc /var
#ips=("1.2.3.5" "6.7.8.9" )
ips=()

#Поиск по словам для поиска в домашних каталогах и файлах
# terms=("айоки")
terms=()

#Поиск папок и путей для поиска подозрительных мест залегания
iocfiles=()
iocfiles="/etc/rc2.d/S04syslogd
/etc/rc3.d/S04syslogd
/etc/rc4.d/S04syslogd
/etc/rc5.d/S04syslogd
/etc/init.d/syslogd
/bin/syslogd
/etc/cron.hourly/syslogd
/tmp/drop
/tmp/srv
$HOME/.local/ssh.txt
$HOME/.local/telnet.txt
$HOME/.local/nodes.cfg
$HOME/.local/check
$HOME/.local/script.bt
$HOME/.local/update.bt
$HOME/.local/server.bt
$HOME/.local/syslog
$HOME/.local/syslog.pid
$HOME/.dbus/sessions/session-dbus 
$HOME/.gvfsd/.profile/gvfsd-helper"

# Определение операционной системы

if [ -f /etc/os-release ]; then
. /etc/os-release
if [[ $ID_LIKE == "debian" ]]; then
    #OS="Debian GNU/Linux"
    OS_LIKE=$ID_LIKE
    OS_NAME=$NAME
elif [[ $ID_LIKE == "fedora" ]]; then
    OS_LIKE="fedora"
    OS_NAME=$NAME
else
    OS_LIKE=$ID
    OS_NAME=$NAME
fi

elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ -f /etc/redhat-release ]; then
    OS=$(cat /etc/redhat-release | awk '{print $1}')
else
    OS=$(uname -s)
fi


# ----------------------------------
# ----------------------------------
# СБОР ДАННЫХ О ХОСТЕ

# Записываем информацию в файл system_file >>>
host_data() {
    echo -n > system_file
    echo -e "${magenta}[Сбор информации о хосте]${clear}" 
    {
        echo "[Текущий хост и время]"  
        echo "Текущая дата и системное время:" 
        date 
        echo -e "\n" 

        echo "[Имя хоста:]" 
        hostname 
        echo -e "\n" 

        echo "[Доп информация о системе из etc/*(-release|_version)]" 
        cat /etc/*release 2>/dev/null
        cat /etc/*version 2>/dev/null
        echo -e "\n" 

        echo "[Доп информация о системе из /etc/issue]" 
        cat /etc/issue 
        echo -e "\n" 

        echo "[Идентификатор хоста (hostid)]" 
        hostid 
        echo -e "\n" 

        echo "[Информация из hostnamectl]" 
        hostnamectl 
        echo -e "\n" 

        echo "[IP адрес(а):]" 
        ip addr  # Информация о текущем IP-адресе
        echo -e "\n" 

        echo "[Информация о системе]" 
        uname -a 
        echo -e "\n" 

        echo "[Подключенные файловые системы:]"
        df -h
        echo -e "\n" 
    } >> system_file
}


# Пользовательские файлы
# ----------------------------------
# ----------------------------------
# Запись в файл users_file >>>

users_list() {
echo -e "${magenta}[Пользовательские файлы]${clear}"

# Список живых пользователей, + записываем имена в переменную для дальнейшего сбора информации
echo "Пользователи с /home/:" 
{
echo "[Пользователи с /home/:]"  
ls /home 
# Исключаем папку lost+found
users=`ls /home -I lost*`
echo $users
echo -e "\n" 

echo "[Текущие авторизированные пользователи:" 
w 
echo -e "\n" 
} >> users_file

{
echo "[Текущий пользователь:]" 
#whoami
who am i 
echo -e "\n" 

echo "[Информация об учетных записях и группах]"
for name in $(ls /home); do
    id $name  
done
echo -e "\n" 



# Поиск новых учетных записей в /etc/passwd
echo "[Поиск новых учетных записей]" 
sort -nk3 -t: /etc/passwd | less
echo -e "\n" 
egrep ':0+: ' /etc/passwd
echo -e "\n" 

echo "[Использование нескольких методов аутентификации]" 
getent passwd | egrep ':0+: '
echo -e "\n" 

# Вывод файлов, которые могут указывать на то, что временная учетная запись злоумышленника была удалена
echo "[Временная учетная запись злоумышленника была удалена]" 
find / -nouser -print
echo -e "\n" 


echo "[Пользовательские файлы из (Downloads,Documents, Desktop)]" 
ls -la /home/*/Downloads 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Загрузки 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Documents 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Документы 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Desktop/ 2>/dev/null 
echo -e "\n" 
ls -la /home/*/Рабочий\ стол/ 2>/dev/null 
echo -e "\n" 

# Составляем список файлов в корзине
echo "[Файлы в корзине из home]" 
ls -laR /home/*/.local/share/Trash/files 2>/dev/null 
echo -e "\n" 

# Для рута тоже на всякий случай
echo "[Файлы в корзине из root]" 
ls -laR /root/.local/share/Trash/files 2>/dev/null 
echo -e "\n" 

# Кешированные изображения могут помочь понять, какие программы использовались
echo "[Кешированные изображения программ из home]" 
ls -la /home/*/.thumbnails/ 2>/dev/null 
echo -e "\n" 
} >> users_file

# Ищем в домашних пользовательских папках
#grep -A2 -B2 -rn 'айоки' --exclude="*FULL.sh" --exclude-dir=$OUTDIR /home/* 2>/dev/null >> ioc_word_info

#Ищем нужные термины в домашних пользовательских папках
#echo "[Ищем ключевые слова...]"

for f in ${terms[@]};
do
    echo "Search $f" 
    echo -e "\n" >> ioc_word_info
    grep -A2 -B2 -rn $f --exclude="*FULL.sh" --exclude-dir=$OUTDIR /home/* 2>/dev/null >> ioc_word_info
done


echo "[Поиск уникальных файловых расширений в папках home и root:]" >> users_file
find /root /home -type f -name \*.exe -o -name \*.jpg -o -name \*.bmp -o -name \*.png -o -name \*.doc -o -name \*.docx -o -name \*.xls -o -name \*.xlsx -o -name \*.csv -o -name \*.odt -o -name \*.ppt -o -name \*.pptx -o -name \*.ods -o -name \*.odp -o -name \*.tif -o -name \*.tiff -o -name \*.jpeg -o -name \*.mbox -o -name \*.eml 2>/dev/null >> users_file
echo -e "\n" >> users_file

# Ищем логи приложений (но не в /var/log)
echo "[Возможные логи приложений (с именем или расширением *log*)]"
find /root /home /bin /etc /lib64 /opt /run /usr -type f -name \*log* 2>/dev/null >> change_files

# Ищем в домашнем каталоге файлы с изменениями (созданием) в определённый временной интервал
#! echo "[Ищем между датами от ${startdate} до ${enddate}]"
# пример запуска:
# find /home/* -type f -newermt "2023-02-24 00:00:11" \! -newermt "2023-02-24 00:53:00" -ls >> change_files
#! find /home/* -type f -newermt "${startdate}" \! -newermt "${enddate}" -ls >> change_files

echo "[Таймлайн файлов в домашних каталогах (CSV)]"
{
echo "file_location_and_name, date_last_Accessed, date_last_Modified, date_last_status_Change, owner_Username, owner_Groupname,sym_permissions, file_size_in_bytes, num_permissions" 
echo -n 
find /home /root -type f -printf "%p,%A+,%T+,%C+,%u,%g,%M,%s,%m\n" 2>/dev/null 
} >> users_file_timeline
}
# Для Astra Linux
echo "[Информация об учетных записях из getent (Astra)]" 
if  uname -a | grep astra; then
    eval getent passwd {$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)..$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)} | cut -d: -f1
    echo -e "\n" 
fi
# <<< Заканчиваем писать файл users_file
# ----------------------------------
# ----------------------------------


# Приложения

# ----------------------------------
# ----------------------------------
# Начинаем писать файл apps_file >>>
app_file() {
echo -e "${magenta}[Приложения в системе]${clear}"

{
echo "[Проверка браузеров]" 
# Firefox, артефакты: ~/.mozilla/firefox/*, ~/.mozilla/firefox/* и ~/.cache/mozilla/firefox/*
firefox --version 2>/dev/null 
# Firefox, альтернативная проверка
dpkg -l | grep firefox 
# Thunderbird. Можно при успехе просмотреть содержимое каталога командой ls -la ~/.thunderbird/*, поискать календарь, сохраненную переписку
thunderbird --version 2>/dev/null 
# Chromium. Артефакты:  ~/.config/chromium/*
chromium --version 2>/dev/null 
# Google Chrome. Артефакты можно брать из ~/.cache/google-chrome/* и ~/.cache/chrome-remote-desktop/chrome-profile/
chrome --version 2>/dev/null 
# Opera. Артефакты ~/.config/opera/*
opera --version 2>/dev/null 
# Brave. Артефакты: ~/.config/BraveSoftware/Brave-Browser/*
brave --version 2>/dev/null 
# Бета Яндекс-браузера для Linux. Артефакты: ~/.config/yandex-browser-beta/*
yandex-browser-beta --version 2>/dev/null 
echo -e "\n" 

echo "[Проверка мессенджеров и других приложений]" 
tdesktop --version 2>/dev/null 
discord --version 2>/dev/null 
dropbox --version 2>/dev/null 
yandex-disk --version 2>/dev/null
echo -e "\n" 
} >> apps_file


{
echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" 
mkdir -p ./artifacts/mozilla
cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla
mkdir -p ./artifacts/gchrome
cp -r /home/*/.config/google-chrome* ./artifacts/gchrome
mkdir -p ./artifacts/chromium
cp -r /home/*/.config/chromium ./artifacts/chromium

echo "[Проверка приложений торрента]"  
apt list --installed 2>/dev/null | grep torrent  
echo -e "\n" 

echo "[Все пакеты, установленные в системе]"  
# Список всех установленных пакетов APT
apt list --installed 2>/dev/null 
echo -e "\n" 
# Список пакетов, установленных вручную
echo "[Все пакеты, установленные в системе (вручную)]"  
apt-mark showmanual 2>/dev/null 
echo -e "\n" 

echo "[Все пакеты, установленные в системе (вручную, вар. 2)]"  
apt list --manual-installed 2>/dev/null | grep -F \[installed\]
echo -e "\n" 

# Вывод для астры списка приложений
echo "[Альтернативный список программ (astra)]"  
echo "[Apps ls -la /usr/share/applications]"
ls /usr/share/applications | awk -F '.desktop' ' { print $1}' - | grep -v -e fly -e org -e okularApplication 
echo -e "\n" 

# Для openSUSE, ALT, Mandriva, Fedora, Red Hat, CentOS
rpm -qa --qf "(%{INSTALLTIME:date}): %{NAME}-%{VERSION}\n" 2>/dev/null 
echo -e "\n" 
# Для Fedora, Red Hat, CentOS
yum list installed 2>/dev/null 
echo -e "\n" 
# Для Fedora
dnf list installed 2>/dev/null 
echo -e "\n" 
# Для Arch
pacman -Q 2>/dev/null 
echo -e "\n" 
# Для openSUSE
zypper info 2>/dev/null 
echo -e "\n" 
echo -e "\n" 

# Запущенные процессы с удалённым исполняемым файлом
echo "[Processes with deleted executable]"  
find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted 
echo -e "\n" 
} >> apps_file
}


# <<< Заканчиваем писать файл apps_file
# ----------------------------------
# ----------------------------------

# Проверка виртуальных приложений и альтернатив мест залегания

# ----------------------------------
# ----------------------------------
# Начинаем писать файл virt_apps_file >>>

virt_apps() {
echo -e "${magenta}[Приложения виртуализации или эмуляции в системе и проверка GRUB]${clear}"

{
echo "[Проверка приложений контейнеризации]" 
docker ps -q | xargs -n 1 docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{.Name}}' | sed 's/ \// /'
docker inspect -f '{{.Name}}: {{.CreatedAt}}' $(docker ps -aq)
echo -e "\n" 

echo "[Вывод содержимого загрузочного меню, то есть список ОС (GRUB)]"  
awk -F\' '/menuentry / {print $2}' /boot/grub/grub.cfg 2>/dev/null 
echo -e "\n" 

echo "[Конфиг файл GRUB]"  
cat /boot/grub/grub.cfg 2>/dev/null 
echo -e "\n" 

echo "[Проверка на наличие загрузочных ОС]"  
os-prober  
echo -e "\n" 
} >> virt_apps_file
}

# <<< Заканчиваем писать файл virt_apps_file
# ----------------------------------
# ----------------------------------

# Активность в ретроспективе
# ----------------------------------
# ----------------------------------
# Начинаем писать файл history_info >>>

history_inf() {
echo -e "${yellow}[Информация по истории]${clear}"
{
# Текущее время работы системы, количество залогиненных пользователей
echo "[Время работы системы, количество залогиненных пользователей]" 
uptime 
echo -e "\n" 

echo "[Журнал перезагрузок (last -x reboot)]" 
last -x reboot 
echo -e "\n" 

echo "[Журнал выключений (last -x shutdown)]" 
last -x shutdown 
echo -e "\n" 

# Список последних входов в систему с указанием даты (/var/log/lastlog)
echo "[Список последних входов в систему (/var/log/lastlog)]" 
lastlog 
echo -e "\n" 

# Список последних залогиненных юзеров (/var/log/wtmp), их сессий, ребутов и включений и выключений
echo "[Список последних залогиненных юзеров с деталями (/var/log/wtmp)]" 
last -Faiwx 
echo -e "\n" 

echo "[Последние команды из fc текущего пользователя]" 
history -a 1 2>/dev/null 
echo -e "\n" 

if ls /root/.*_history >/dev/null 2>&1; then
    echo "[История root-а (/root/.*history)]" 
    more /root/.*history | cat 
	echo -e "\n" 
fi

for name in $(ls /home); do
    echo "[История пользоватея ${name} (.*history)]" 
    more /home/$name/.*history 2>/dev/null | cat    
    echo -e "\n" 
	echo "[История команд Python пользоватея ${name}]" 
	more /home/$name/.python_history 2>/dev/null | cat 
	echo -e "\n" 
done

echo "[История установленных приложений из /var/log/dpkg.log]" 
grep "install " /var/log/dpkg.log 
echo -e "\n" 

# История установки пакетов в архивных логах
echo "[Архив истории установленных приложений из /var/log/dpkg.log.gz ]" 
zcat /var/log/dpkg.log.gz | grep "install " 
echo -e "\n" 

echo "[История обновленных приложений из /var/log/dpkg.log]" 
grep "upgrade " /var/log/dpkg.log 
echo -e "\n" 

echo "[История удаленных приложений из /var/log/dpkg.log]" 
grep "remove " /var/log/dpkg.log 
echo -e "\n" 

echo "[История о последних apt-действиях (history.log)]" 
cat /var/log/apt/history.log 
echo -e "\n" 
} >> history_info 
}

# <<< Заканчиваем писать файл history_info
# ----------------------------------
# ----------------------------------

# Информация по сети

# ----------------------------------
# ----------------------------------
# Начинаем писать файл network_info >>>


network_inf() {
echo -e "${blue}[Проверка сетевой информации]${clear}"

{
# Информация о сетевых адаптерах
echo "[IP адрес(а):]" 
ip l 
echo -e "\n" 

echo "[Настройки сети]" 
ifconfig -a 2>/dev/null 
echo -e "\n" 

echo "[Сетевые интерфейсы (конфиги)]" 
cat /etc/network/interfaces 
echo -e "\n" 

echo "[Настройки DNS]" 
cat /etc/resolv.conf 
cat /etc/host.conf    2>/dev/null 
echo -e "\n" 

echo "[Сетевой менеджер (nmcli)]" 
nmcli 
echo -e "\n" 

echo "[Беспроводные сети (iwconfig)]" 
iwconfig 2>/dev/null 
echo -e "\n" 

echo "[Информация из hosts (local DNS)]" 
cat /etc/hosts 
echo -e "\n" 

echo "[Сетевое имя машины (hostname)]" 
cat /etc/hostname 
echo -e "\n" 

echo "[Сохраненные VPN ключи]" 
ip xfrm state list 
echo -e "\n" 

echo "[ARP таблица]" 
arp -e 2>/dev/null 
echo -e "\n" 

echo "[Таблица маршрутизации]" 
ip r 2>/dev/null 
# route 2>/dev/null 
echo -e "\n" 

echo "[Проверка настроенных прокси]" 
echo "$http_proxy" 
echo -e "\n" 
echo "$https_proxy"
echo -e "\n" 
env | grep proxy 
echo -e "\n" 

# База аренд DHCP-сервера (файлы dhcpd.leases)
echo "[Проверяем информацию из DHCP]" 
more /var/lib/dhcp/* 2>/dev/null | cat 
# Основные конфиги DHCP-сервера
more /etc/dhcp/* | cat | grep -vE ^ 2>/dev/null 
# Информация о назначенном адресе по DHCP
journalctl |  grep  " lease" 
# При установленном NetworkManager
journalctl |  grep  "DHCP" 
echo -e "\n" 
# Информация о DHCP-действиях на хосте
journalctl | grep -i dhcpd 
echo -e "\n" 

echo "[Сетевые процессы и сокеты с адресами]" 
# Активные сетевые процессы и сокеты с адресами
netstat -nap 2>/dev/null 
netstat -anoptu 2>/dev/null 
netstat -rn 2>/dev/null 
# Вывод имен процессов с текущими TCP/UDP-соединениями (только под рутом)
ss -tupln 2>/dev/null 
echo -e "\n" 

echo "[Количество сетевых полуоткрытых соединений]" 
netstat -tan | grep -i syn | wc -с
netstat -tan | grep -с -i syn 2>/dev/null 
echo -e "\n" 

echo "[Сетевые соединения (lsof -i)]" 
lsof -i 
echo -e "\n" 
} >> network_info 

{
echo "[Network connections list - connection]" 
journalctl -u NetworkManager | grep -i "connection '" 
echo -e "\n" 
echo "[Network connections list - addresses]" 
journalctl -u NetworkManager | grep -i "address"

echo -e "\n" 
echo "[Network connections wifi enabling]" 
journalctl -u NetworkManager | grep -i wi-fi
echo -e "\n" 

echo "[Network connections internet]" 
journalctl -u NetworkManager | grep -i global -A2 -B2
echo -e "\n" 

echo "[Подключаемые сети Wi-Fi]"  
grep psk= /etc/NetworkManager/system-connections/* 2>/dev/null 
echo -e "\n"

echo "[Конфигурация firewall]"  
iptables-save 2>/dev/null 
echo -e "\n" 
iptables -n -L -v --line-numbers 
echo -e "\n" 

# Список правил файрвола nftables
echo "[Firewall configuration nftables]"  
nft list ruleset 
echo -e "\n" 

echo "[Поиск неразборчивого режима]"  
ip link | grep PROMISC
echo -e "\n" 
} >> network_add_info


# Ищем IP-адреса в логах и выводим список
#journalctl | grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]| sudo [01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' | sort |uniq
#grep -r -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)' /var/log | sort | uniq

# Ищем IP среди данных приложений
#grep -A2 -B2 -rn '66.66.55.42' --exclude="*FULL.sh" --exclude-dir=$OUTDIR /usr /etc  2>/dev/null 

# Ищем IP в логах или конфигах приложений, как вариант

echo "[Ищем IP-адреса в текстовых файлах...]"
for f in ${ips[@]};
do
    echo "Search $f" 
    echo -e "\n" 
    grep -A2 -B2 -rn $f --exclude="*FULL.sh" --exclude-dir=$OUTDIR /usr /etc /var 2>/dev/null 
done
}

#} >> IP_search_info


# <<< Заканчиваем писать файл network_info
# ----------------------------------
# ----------------------------------

# Активные демоны, процессы, задачи и их конфигурации
# ----------------------------------
# ----------------------------------
# Начинаем писать файл process_info >>>

process_inf() {
echo -e "${magenta}[Проверка процессов, планировщиков и тд]${clear}"

{
echo "[Список текущих активных сессий (Screen)]"  
screen -ls 2>/dev/null 
echo -e "\n" 

echo "[Фоновые задачи (jobs)]"  
jobs 
echo -e "\n" 

echo "[Задачи в планировщике (Crontab)]" 
crontab -l 2>/dev/null 
echo -e "\n" 
} >> process_info 

{
echo "[Задачи в планировщике (Crontab) в файлах /etc/cron*]" 
more /etc/cron*/* | cat 
echo -e "\n" 

echo "[Вывод запланированных задач для всех юзеров (Crontab)]" 
for user in $(ls /home/); do echo $user; crontab -u $user -l;   echo -e "\n"  ; done
echo -e "\n" 

echo "[Лог планировщика (Crontab) в файлах /etc/cron*]" 
more /var/log/cron.log* | cat 
echo -e "\n" 
} >> cronconf_info

{
echo "[Задачи в планировщике (Crontab) в файлах /etc/crontab]" 
cat /etc/crontab 
echo -e "\n" 

echo "[Автозагрузка графических приложений (файлы с расширением .desktop)]"  
ls -la  /etc/xdg/autostart/* 2>/dev/null   
echo -e "\n" 

echo "[Быстрый просмотр всех выполняемых команд через автозапуски (xdg)]"  
cat  /etc/xdg/autostart/* | grep "Exec=" 2>/dev/null   
echo -e "\n" 

echo "[Автозагрузка в GNOME и KDE]"  
more  /home/*/.config/autostart/*.desktop 2>/dev/null | cat  
echo -e "\n" 

echo "[Задачи из systemctl list-timers (предстоящие задачи)]" >> system_file
systemctl list-timers 
echo -e "\n" 

echo "[Список процессов (ROOT)]" 
ps -l 
echo -e "\n" 

echo "[Список процессов (все)]" 
ps aux 
ps -eaf
echo -e "\n" 

#Если на хосте установлена chkconfig
echo "[Список всех доступных служб и их обновлений]" 
chkconfig –list
echo -e "\n"
} >> process_info

{
echo "[Дерево процессов]" 
pstree -aups
echo -e "\n" 
} >> pstree_file

{
echo "[Файлы с выводом в /dev/null]" 
lsof -w /dev/null 
echo -e "\n" 
} >> lsof_file

{
# Текстовый вывод аналога виндового диспетчера задач
echo "[Инфа о процессах через top]" 
top -bcn1 -w512  
echo -e "\n" 

echo "[Вывод задач в бэкграунде atjobs]" 
ls -la /var/spool/cron/atjobs 2>/dev/null 
echo -e "\n" 

echo "[Вывод jobs из var/spool/at/]" 
more /var/spool/at/* 2>/dev/null | cat 
echo -e "\n" 

echo "[Файлы deny|allow со списками юзеров, которым разрешено в cron или jobs]" 
more /etc/at.* 2>/dev/null | cat 
echo -e "\n" 

echo "[Вывод задач Anacron]" 
more /var/spool/anacron/cron.* 2>/dev/null | cat 
echo -e "\n" 

echo "[Пользовательские скрипты в автозапуске rc (legacy-скрипт, который выполняется перед логоном)]" 
more /etc/rc*/* 2>/dev/null | cat 
more /etc/rc.d/* 2>/dev/null | cat 
echo -e "\n" 
} >> process_info 

echo -e "${green}[Пакуем LOG-файлы (/var/log/)...]${clear}"
echo "[Пакуем LOG-файлы...]" >> process_info 


# /var/log/
tar -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null

#/var/log/auth.log Аутентификация
#/var/log/cron.log Cron задачи
#/ var / log / maillog Почта
#/ var / log / httpd Apache
# Подробнее: https://www.securitylab.ru/analytics/520469.php

grep "entered promiscuous mode" /var/log/syslog

}

# <<< Заканчиваем писать файл process_info
# ----------------------------------
# ----------------------------------

# Активные службы и их конфиги
# (и типовые места закрепления вредоносов, часть 2)

# ----------------------------------
# ----------------------------------
# Начинаем писать файл services_info >>>

services_inf() {
echo -e "${cyan}[Проверка сервисов в системе]${clear}"

{
echo "[Список активных служб systemd]"  
systemctl list-units  
echo -e "\n" 

echo "[Список всех служб]"  
# можно отдельно посмотреть модули ядра: cat /etc/modules.conf и cat /etc/modprobe.d/*
systemctl list-unit-files --type=service 
echo -e "\n" 

echo "[Статус работы всех служб (командой service)]"  
service --status-all 2>/dev/null 
echo -e "\n" 
} >> services_info 

{
echo "[Вывод конфигураций всех сервисов]"  
more /etc/systemd/system/*.service | cat 
echo -e "\n" 
} >> services_configs

{
echo "[Список запускаемых сервисов (init)]"  
ls -la /etc/init  2>/dev/null 
echo -e "\n" 

echo "[Сценарии запуска и остановки демонов (init.d)]"  
ls -la /etc/init.d  2>/dev/null 
echo -e "\n" 
} >> services_info
}

# <<< Заканчиваем писать файл services_info
# ----------------------------------
# ----------------------------------

# ----------------------------------
# ----------------------------------
# Начинаем писать файл devices_info >>>

devices_inf() {
echo -e "${magenta}[Информация об устройствах]${clear}"
{
echo "[Информация об устройствах (lspci)]" 
lspci 
echo -e "\n" 

echo "[Устройства USB (lsusb)]" 
lsusb 
echo -e "\n" 

echo "[Блочные устройства (lsblk)]" 
lsblk 
echo -e "\n" 
more /sys/bus/pci/devices/*/* 2>/dev/null | cat 
echo -e "\n" 

echo "[Список примонтированных файловых систем (findmnt)]" 
findmnt 
echo -e "\n" 

echo "[Bluetooth устройства (bt-device -l)]" 
bt-device -l 2>/dev/null 
echo -e "\n" 

echo "[Bluetooth устройства (hcitool dev)]" 
hcitool dev 2>/dev/null 
echo -e "\n" 

echo "[Bluetooth устройства (/var/lib/bluetooth)]" 
ls -laR /var/lib/bluetooth/ 2>/dev/null 
echo -e "\n" 

echo "[Устройства USB (usbrip)]" 
usbrip events history 2>/dev/null 
echo -e "\n" 

echo "[Устройства USB из dmesg]" 
dmesg | grep -i usb 2>/dev/null 
echo -e "\n" 

echo "[Устройства USB из journalctl]"  
journalctl -o short-iso-precise | grep -iw usb
echo -e "\n" 

echo "[Устройства USB из syslog]" 
cat /var/log/syslog* | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 

echo "[Устройства USB из (log messages)]" 
cat /var/log/messages* | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null 
echo -e "\n" 

echo "[Устройства USB (dmesg)]" 
dmesg | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 
echo "[Устройства USB (journalctl)]" 
journalctl | grep -i usb | grep -A1 -B2 -i SerialNumber: 
echo -e "\n" 

echo "[Другие устройства из journalctl]" 
journalctl| grep -i 'PCI|ACPI|Plug' 2>/dev/null 
echo -e "\n" 

echo "[Подключение/отключение сетевого кабеля (адаптера) из journalctl]" 
journalctl | grep "NIC Link is" 2>/dev/null 
echo -e "\n" 

# Открытие/закрытие крышки ноутбука
echo "[LID open-downs:]"  
journalctl | grep "Lid"  2>/dev/null  
echo -e "\n" 
} >> devices_info
}

# <<< Заканчиваем писать файл devices_info
# ----------------------------------
# ----------------------------------

# Закрепы вредоносов
# собираем инфу и конфиги для последующего анализа

# ----------------------------------
# ----------------------------------
# Начинаем писать файл env_profile_info >>>

env_profile_inf() {
echo -e "${cyan}[Информация о переменных системы, шелле и профилях пользователей]${clear}"
{
echo "[Глобальные переменные среды ОС (env)]" 
env 
echo -e "\n" 

echo "[Все текущие переменные среды]" 
printenv 
echo -e "\n" 

echo "[Переменные шелла]" 
set 
echo -e "\n" 

echo "[Расположение исполняемых файлов доступных шеллов:]" 
cat /etc/shells 2>/dev/null 
echo -e "\n" 

if [ -e "/etc/profile" ] ; then
    echo "[Содержимое из /etc/profile]" 
    cat /etc/profile 2>/dev/null 
    echo -e "\n" 
fi
} >> env_profile_info

{
echo "[Содержимое из файлов /home/users/.*]" 
for name in $(ls /home); do
    #more /home/$name/.*_profile 2>/dev/null | cat 
	echo Hidden config-files for: $name 
	more /home/$name/.* 2>/dev/null | cat  
    echo -e "\n" 
done
} >> usrs_cfgs

{
echo "[Содержимое скрытых конфигов рута - cat ROOT /root/.* (homie directory content + history)]" 
more /root/.* 2>/dev/null | cat 
echo -e "\n" 
} >> root_cfg

# Список файлов, пример
#.*_profile (.profile)
#.*_login
#.*_logout
#.*rc
#.*history 
{
echo "[Пользователи SUDO]" 
cat /etc/sudoers 2>/dev/null 
echo -e "\n" 
} >> env_profile_info
}

# <<< Заканчиваем писать файл env_profile_info
# ----------------------------------
# ----------------------------------

#! - начало для файла interest_file

# ----------------------------------
# ----------------------------------
# Начинаем писать файл interest_file >>>

interest_fil() {
echo -e "${cyan}[Rootkits, IOCs]${clear}"
{
# Проверимся на руткиты
echo "[Проверка на rootkits командой chkrootkit]" 
chkrootkit 2>/dev/null 
echo -e "\n" 
} >> interest_file

echo -e "${yellow}[IOC-и файлов]${clear}"
echo "[IOC-paths?]" >> interest_file
echo -e "\n" >> interest_file

counter=0;
for f in $iocfiles
do
if [ -e $f ]
then 
	counter=$((counter+1))
	echo -e "${red}IOC-path found: ${clear}" $f
	echo "IOC-path found: " $f >> interest_file
	echo -e "\n" >> interest_file
fi
done

if [ $counter -gt 0 ]
then 
	echo -e "${red}IOC Markers found!!${clear}" 
	echo "IOC Markers found!!" >> interest_file
	echo -e "\n" >> interest_file
fi

{
echo "[BIOS TIME]" 
hwclock -r 2>/dev/null 
echo -e "\n" 
echo "[SYSTEM TIME]" 
date 
echo -e "\n" 

# privilege information
echo "[PRIVILEGE passwd - all users]" 
cat /etc/passwd 2>/dev/null 
echo -e "\n" 

# ssh keys
echo "[Additional info cat ssh (root) keys and hosts]" 
cat /root/.ssh/authorized_keys 2>/dev/null 
cat /root/.ssh/known_hosts 2>/dev/null 
echo -e "\n" 

#for users:
echo "[Additional info cat ssh (users) keys and hosts]" 
for name in $(ls /home)
do
echo SSH-files for: $name 
cat /home/$name/.ssh/authorized_keys 2>/dev/null 
echo -e "\n" 
cat /home/$name/.ssh/known_hosts 2>/dev/null 
done
echo -e "\n" 

# VM - detection
echo "[Virtual Machine Detection]" 
dmidecode -s system-manufacturer 2>/dev/null 
echo -e "\n" 
dmidecode  2>/dev/null 
echo -e "\n" 

# HTTP server inforamtion collection
# Nginx collection
echo "[Nginx Info]" 
echo -e "\n" 
# tar default directory
if [ -e "/usr/local/nginx" ] ; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_nginx.tar.gz /usr/local/nginx 2>/dev/null
	echo "Grab NGINX files!" 
	echo -e "\n" 
fi

# Apache2 collection
echo "[Apache Info]" 
echo -e "\n" 
# tar default directory
if [ -e "/etc/apache2" ] ; then
    tar -zc -f ./artifacts/HTTP_SERVER_DIR_apache.tar.gz /etc/apache2 2>/dev/null
	echo "Grab APACHE files!" 
	echo -e "\n" 
fi

# Install files
echo "[Core modules - lsmod]" 
lsmod 
echo -e "\n" 

echo "[Пустые пароли]" 
cat /etc/shadow | awk -F: '($2==""){print $1}' 
echo -e "\n" 

# .bin
echo "[Malware collection]" 

find / -name \*.bin 
echo -e "\n" 

find / -name \*.exe 
echo -e "\n" 

find /home -name \*.sh 2>/dev/null
echo -e "\n" 

find /home -name \*.py 2>/dev/null
echo -e "\n" 

#find copied
# Find nouser or nogroup  data
echo "[NOUSER files]" 
find /root /home -nouser 2>/dev/null 
echo -e "\n" 

echo "[NOGROUP files]" 
find /root /home -nogroup 2>/dev/null 
echo -e "\n" 

} >> interest_file

{
# Поиск всех процессов, у которых в командной строке встречается строка "nc" или "netcat"
echo "[Поиск Reverse Shell]" 
ps aux | grep -E '(nc|netcat|ncat|socat)'
echo -e "\n"

#попытка шелла на java
echo "[Поиск java shell]"
grep -rPl 'Runtime\.getRuntime\(\)\.exec\(|ProcessBuilder\(\)|FileOutputStream\(|FileWriter\(|URLClassLoader\(|ClassLoader\.defineClass\(|ScriptEngine\(.+\.eval\(|setSecurityManager\(null\)' /home/*/ /usr/bin /opt/application 2>/dev/null 2>/dev/null
echo -e "\n"

#поиск шелла на php
echo "[Поиск php shell]"
grep -rPl '(?:eval\(|assert\(|base64_decode|gzinflate|\$_(GET|POST|REQUEST|COOKIE|SESSION)|passthru|shell_exec|system|[^]+`|preg_replace\s*\(.*\/e[^,]*,)' /bin /etc /home /usr  /var /dev /tmp /srv /boot /opt 2>/dev/null
echo -e "\n"
} >> shell_file

{
echo "[lsof -n]" 
lsof -n 2>/dev/null
echo -e "\n" 

echo "[Verbose open files: lsof -V ]"  #open ports
lsof -V  
echo -e "\n" 
} >> lsof_file

{
if [ -e /var/log/btmp ]
	then 
	echo "[Last LOGIN fails: lastb]" 
	lastb 2>/dev/null 
	echo -e "\n" 
fi

if [ -e /var/log/wtmp ]
	then 
	echo "[Login logs and reboot: last -f /var/log/wtmp]" 
	last -f /var/log/wtmp 
	echo -e "\n" 
fi

if [ -e /etc/inetd.conf ]
then
	echo "[inetd.conf]" 
	cat /etc/inetd.conf 
	echo -e "\n" 
fi

echo "[File system info: df -k in blocks]" 
df -k 
echo -e "\n" 

echo "[File system info: df -Th in human format]" 
df -Th 
echo -e "\n" 

echo "[List of mounted filesystems: mount]" 
mount 
echo -e "\n" 

echo "[kernel messages: dmesg]" 
dmesg 2>/dev/null 
echo -e "\n" 

echo "[Repo info: cat /etc/apt/sources.list]"  
cat /etc/apt/sources.list 
echo -e "\n" 

echo "[Static file system info: cat /etc/fstab]"  
cat /etc/fstab 2>/dev/null 
echo -e "\n" 

echo "[Virtual memory state: vmstat]"  
vmstat 
echo -e "\n" 

echo "[HD devices check: dmesg | grep hd]"  
dmesg | grep -i hd 2>/dev/null 
echo -e "\n" 

# Show activity log
echo "[Get log messages: cat /var/log/messages]"  
cat /var/log/messages 2>/dev/null 
echo -e "\n" 

echo "[USB check 3 Try: cat /var/log/messages]"  
cat /var/log/messages | grep -i usb 2>/dev/null 
echo -e "\n" 

echo "[List all mounted files and drives: ls -lat /mnt]"  
ls -lat /mnt 
echo -e "\n" 

echo "[Disk usage: du -sh]"  
du -sh 
echo -e "\n" 

echo "[Disk partition info: fdisk -l]"  
fdisk -l 2>/dev/null 
echo -e "\n" 

echo "[Additional info - OS version cat /proc/version]" 
cat /proc/version 
echo -e "\n" 

echo "[Additional info lsb_release (distribution info)]" 
lsb_release 2>/dev/null 
echo -e "\n" 

echo "[Query journal: journalctl]"  
journalctl 
echo -e "\n" 

echo "[Memory free]"  
free 
echo -e "\n" 

echo "[Hardware: lshw]"  
lshw 2>/dev/null 
echo -e "\n" 

echo "[Hardware info: cat /proc/(cpuinfo|meminfo)]"  
cat /proc/cpuinfo 
echo -e "\n" 
cat /proc/meminfo 
echo -e "\n" 

echo "[/sbin/sysctl -a (core parameters list)]"  
/sbin/sysctl -a 2>/dev/null 
echo -e "\n" 

echo "[Profile parameters: cat /etc/profile.d/*]"  
cat /etc/profile.d/* 2>/dev/null 
echo -e "\n" 

echo "[Language locale]"  
locale  2>/dev/null 
echo -e "\n" 

#manual installed
echo "[Get manually installed packages apt-mark showmanual (TOP)]"  
apt-mark showmanual 2>/dev/null 
echo -e "\n" 

echo "[Get manually installed packages apt list --manual-installed | grep -F \[installed\]]"  
apt list --manual-installed 2>/dev/null | grep -F \[installed\]  
echo -e "\n" 

mkdir -p ./artifacts/config_root
#desktop icons and other_stuff
cp -r /root/.config ./artifacts/config_root 2>/dev/null 
#saved desktop sessions of users
cp -R /root/.cache/sessions ./artifacts/config_root 2>/dev/null 

echo "[VMware clipboard (root)!]" 
ls -laR /root/.cache/vmware/drag_and_drop/ 2>/dev/null 
echo -e "\n" 

echo "[Mails of root]" 
cat /var/mail/root 2>/dev/null 
echo -e "\n" 

cp -R ~/.config/ 2>/dev/null 

echo "[Apps ls -la /usr/share/applications]"  
ls -la /usr/share/applications 
ls -la /home/*/.local/share/applications/ 
echo -e "\n" 

#recent 
echo "[Recently-Used]"  
more  /home/*/.local/share/recently-used.xbel 2>/dev/null | cat 
echo -e "\n"  

echo "[Var-LIBS directories - like program list]"  
ls -la /var/lib 2>/dev/null  
echo -e "\n" 

echo "[Some encypted data?]"  
cat /etc/crypttab 2>/dev/null  
echo -e "\n" 

echo "[User dirs default configs]"  
cat /etc/xdg/user-dirs.defaults  2>/dev/null  
echo -e "\n"       

echo "[OS-release:]"  
cat /etc/os-release 2>/dev/null  
echo -e "\n" 

echo "[List of boots]"  
journalctl --list-boots  2>/dev/null  
echo -e "\n" 

echo "[Machine-ID:]"  
cat /etc/machine-id 2>/dev/null 
echo -e "\n" 

echo "[SSL certs and keys:]"  
ls -laR /etc/ssl    2>/dev/null  
echo -e "\n" 

echo "[GnuPG contains:]"  
ls -laR /home/*/.gnupg/* 2>/dev/null  
echo -e "\n" 

} >> interest_file

echo "[Web collection]"
{
echo "[Web collection start...]" 
mkdir -p ./artifacts/mozilla
cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla 

echo "[Look through (SSH) service logs for errors]" 
journalctl _SYSTEMD_UNIT=sshd.service | grep “error” 2>/dev/null 
echo -e "\n" 
} >> interest_file

echo "Get users Recent and personalize collection" >> interest_file

for usa in $users
do
	mkdir -p ./artifacts/share_user/$usa
	cp -r /home/$usa/.local/share ./artifacts/share_user/$usa 2>/dev/null 
done

rm -r ./artifacts/share_user/$usa/Trash 2>/dev/null 
rm -r ./artifacts/share_user/$usa/share/Trash/files 2>/dev/null 

mkdir -p ./artifacts/share_root
cp -r /root/.local/share ./artifacts/share_root 2>/dev/null 
rm -r ./artifacts/share_root/Trash 2>/dev/null 
rm -r ./artifacts/share_root/share/Trash/files 2>/dev/null 
ls -la /home/*/.local/share/applications/ 

mkdir -p ./artifacts/config_user
cp -r /home/*/.config ./config_user
for usa in $users
do
	mkdir -p ./artifacts/config_user/$usa
	#desktop icons and other_stuff
	cp -r /home/$usa/.config ./artifacts/config_user/$usa 2>/dev/null 

	#saved desktop sessions of users
	cp -R /home/$usa/.cache/sessions ./artifacts/config_user/$usa 2>/dev/null 
	
	{
	#check mail:
	echo "[Mails of $usa:]" 
	cat /var/mail/$usa 2>/dev/null 
	echo -e "\n" 

	echo "[VMware clipboard]" 
	ls -laR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null 
	echo -e "\n" 
	} >> interest_file
done
}


# <<< Заканчиваем писать файл interest_file
# ----------------------------------
# ----------------------------------

#! - начало для файла interest_file

# ----------------------------------
# ----------------------------------
# Начинаем писать файл mitre_ioc_file >>>


mitre_ioc() {
    echo "[Detect log4j IOC]"
    printf "| %-40s |\n" "`date`"

    #echo "[Initial_Access]"
    echo "[Поиск попыток эксплуатации в файлах по пути /var/log]"
    sudo egrep -I -i -r '\$(\{|%7B)jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):/[^\n]+' /var/log
    echo -e "\n" 

    sudo find /var/log -name \*.gz -print0 | xargs -0 zgrep -E -i '\$(\{|%7B)jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):/[^\n]+'
    echo -e "\n" 

    echo "[Поиск обфусцированных вариантов]"
    sudo find /var/log/ -type f -exec sh -c "cat {} | sudo sed -e 's/\${lower://'g | tr -d '}' | sudo egrep -I -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \;
    echo -e "\n" 
    sudo find /var/log/ -name '*.gz' -type f -exec sh -c "zcat {} | sudo sed -e 's/\${lower://'g | tr -d '}' | sudo egrep -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \;
    echo -e "\n" 
} >> mitre_ioc_file


# <<< Заканчиваем писать файл mitre_ioc_file
# ----------------------------------
# ----------------------------------
# Архивируем
archive() {
	echo "Архивация артефактов"
	tar --remove-files -zc -f ./artifacts.tar.gz artifacts 2>/dev/null

	{  
	echo "Сбор артефактов завершен" 
	date 
	echo -e "\n" 
	} >> system_file
}

# Для выходной директории даем права всем на чтение и удаление
change_rights() {
 chmod -R ugo+rwx ./../$OUTDIR
 end=`date +%s`
 echo -e "\n" 
 echo ENDED! Execution time was $(expr $end - $start) seconds.
 echo -e "${magenta}Проверяй директорию ${OUTDIR}! ${clear}"
 pathe=$(readlink -f $OUTDIR)
 echo -e "${yellow}Полный путь: ${pathe}! ${clear}"

xdg-open . 2>/dev/null
}
 
user_list_for_fedora(){
    echo -e "${magenta}[Пользовательские файлы]${clear}"
    echo -n > users_file
    {
        echo "[Пользователи с /home/:]"  
        ls /home 
        users=$(ls /home)
        echo $users
        echo -e "\n" 

        echo "[Текущие авторизированные пользователи:" 
        w 
        echo -e "\n" 

        echo "[Текущий пользователь:]" 
        who am i 
        echo -e "\n" 

        echo "[Информация об учетных записях и группах]"
        for name in $users; do
            id $name  
        done
        echo -e "\n" 

        echo "[Поиск новых учетных записей]" 
        sort -nk3 -t: /etc/passwd | less
        echo -e "\n" 
        egrep ':0+: ' /etc/passwd
        echo -e "\n" 

        echo "[Использование нескольких методов аутентификации]" 
        getent passwd | egrep ':0+: '
        echo -e "\n" 

        echo "[Временная учетная запись злоумышленника была удалена]" 
        find / -nouser -print
        echo -e "\n" 

        echo "[Пользовательские файлы из (Downloads, Documents, Desktop)]" 
        ls -la /home/*/Downloads 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Documents 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Desktop/ 2>/dev/null 
        echo -e "\n" 

        echo "[Файлы в корзине из home]" 
        ls -laR /home/*/.local/share/Trash/files 2>/dev/null 
        echo -e "\n" 

        echo "[Файлы в корзине из root]" 
        ls -laR /root/.local/share/Trash/files 2>/dev/null 
        echo -e "\n" 

        echo "[Кешированные изображения программ из home]" 
        ls -la /home/*/.thumbnails/ 2>/dev/null 
        echo -e "\n" 

        echo "[Поиск уникальных файловых расширений в папках home и root:]" 
        find /root /home -type f \( -name \*.exe -o -name \*.jpg -o -name \*.bmp -o -name \*.png -o -name \*.doc -o -name \*.docx -o -name \*.xls -o -name \*.xlsx -o -name \*.csv -o -name \*.odt -o -name \*.ppt -o -name \*.pptx -o -name \*.ods -o -name \*.odp -o -name \*.tif -o -name \*.tiff -o -name \*.jpeg -o -name \*.mbox -o -name \*.eml \) 2>/dev/null >> users_file 
        echo -e "\n" >> users_file

        echo "[Возможные логи приложений (с именем или расширением *log*)]"
        find /root /home /bin /etc /lib64 /opt /run /usr -type f -name \*log* 2>/dev/null >> change_files
        echo -e "\n" >> change_files
    } >> users_file
    echo "[Таймлайн файлов в домашних каталогах (CSV)]"
    {
        echo "file_location_and_name, date_last_Accessed, date_last_Modified, date_last_status_Change, owner_Username, owner_Groupname,sym_permissions, file_size_in_bytes, num_permissions" 
        echo -n 
        find /home /root -type f -printf "%p,%A+,%T+,%C+,%u,%g,%M,%s,%m\n" 2>/dev/null 
    } >> users_file_timeline
}
app_file_for_fedora() {
    echo -e "${magenta}[Приложения в системе]${clear}"

    {
        echo "[Проверка браузеров]" 
        firefox --version 2>/dev/null 
        thunderbird --version 2>/dev/null 
        chromium --version 2>/dev/null 
        google-chrome --version 2>/dev/null 
        opera --version 2>/dev/null 
        brave --version 2>/dev/null 
        yandex-browser-beta --version 2>/dev/null 
        echo -e "\n" 

        echo "[Проверка мессенджеров и других приложений]" 
        tdesktop --version 2>/dev/null 
        discord --version 2>/dev/null 
        dropbox --version 2>/dev/null 
        yandex-disk --version 2>/dev/null
        echo -e "\n" 
    } >> apps_file

    {
        echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" 
        mkdir -p ./artifacts/mozilla
        cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla
        mkdir -p ./artifacts/gchrome
        cp -r /home/*/.config/google-chrome* ./artifacts/gchrome
        mkdir -p ./artifacts/chromium
        cp -r /home/*/.config/chromium ./artifacts/chromium

        echo "[Проверка приложений торрента]"  
        dnf list installed 2>/dev/null | grep torrent  
        echo -e "\n" 

        rpm -qa --qf "(%{INSTALLTIME:date}): %{NAME}-%{VERSION}\n" 2>/dev/null 
        echo -e "\n" 

        echo "[Все пакеты, установленные в системе]"  
        dnf list installed 2>/dev/null 
        echo -e "\n" 

        echo "[Запущенные процессы с удалённым исполняемым файлом]"  
        find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted 
        echo -e "\n" 
    } >> apps_file
}

virt_apps_for_fedora() {
    echo -e "${magenta}[Приложения виртуализации или эмуляции в системе и проверка GRUB]${clear}"

    {
        echo "[Проверка приложений контейнеризации]" 
        docker ps -q | xargs -n 1 docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{.Name}}' | sed 's/ \// /'
        docker inspect -f '{{.Name}}: {{.CreatedAt}}' $(docker ps -aq)
        echo -e "\n" 

        echo "[Вывод содержимого загрузочного меню, то есть список ОС (GRUB)]"  
        awk -F\' '/menuentry / {print $2}' /boot/grub2/grub* 2>/dev/null 
        echo -e "\n" 

        echo "[Конфиг файл GRUB]"  
        cat /boot/grub2/grub* 2>/dev/null 
        echo -e "\n" 

        echo "[Проверка на наличие загрузочных ОС]"  
        os-prober  
        echo -e "\n" 
    } >> virt_apps_file
}

history_inf_for_fedora() {
    echo -e "${yellow}[Информация по истории]${clear}"
    {
        echo "[Время работы системы, количество залогиненных пользователей]" 
        uptime 
        echo -e "\n" 

        echo "[Журнал перезагрузок (last -x reboot)]" 
        last -x reboot 
        echo -e "\n" 

        echo "[Журнал выключений (last -x shutdown)]" 
        last -x shutdown 
        echo -e "\n" 

        echo "[Список последних входов в систему (/var/log/lastlog)]" 
        lastlog 
        echo -e "\n" 

        echo "[Список последних залогиненных юзеров с деталями (/var/log/wtmp)]" 
        last -Faiwx 
        echo -e "\n" 

        echo "[Последние команды из fc текущего пользователя]" 
        history -a 1 2>/dev/null 
        echo -e "\n" 

        if ls /root/.*_history >/dev/null 2>&1; then
            echo "[История root-а (/root/.*history)]" 
            more /root/.*history | cat 
            echo -e "\n" 
        fi

        for name in $(ls /home); do
            echo "[История пользоватея ${name} (.*history)]" 
            more /home/$name/.*history 2>/dev/null | cat    
            echo -e "\n" 
            echo "[История команд Python пользоватея ${name}]" 
            more /home/$name/.python_history 2>/dev/null | cat 
            echo -e "\n" 
        done

        echo "[История установленных приложений из /var/log/dnf.log]" 
        grep "install " /var/log/dnf.log 
        echo -e "\n" 

        echo "[История обновленных приложений из /var/log/dnf.log]" 
        grep "upgrade " /var/log/dnf.log 
        echo -e "\n" 

        echo "[История удаленных приложений из /var/log/dnf.log]" 
        grep "remove " /var/log/dnf.log 
        echo -e "\n" 

        echo "[История о последних dnf-действиях (history)]" 
        dnf history 
        echo -e "\n" 
    } >> history_info 
}

network_inf_for_fedora() {
    echo -e "${blue}[Проверка сетевой информации]${clear}"

    {
        echo "[IP адрес(а):]" 
        ip l 
        echo -e "\n" 

        echo "[Настройки сети]" 
        ip addr show 2>/dev/null 
        echo -e "\n" 

        echo "[Настройки DNS]" 
        cat /etc/resolv.conf 
        cat /etc/host.conf    2>/dev/null 
        echo -e "\n" 

        echo "[Сетевой менеджер (nmcli)]" 
        nmcli 
        echo -e "\n" 

        echo "[Беспроводные сети (iwconfig)]" 
        iwconfig 2>/dev/null 
        echo -e "\n" 

        echo "[Информация из hosts (local DNS)]" 
        cat /etc/hosts 
        echo -e "\n" 

        echo "[Сетевое имя машины (hostname)]" 
        cat /etc/hostname 
        echo -e "\n" 

        echo "[Сохраненные VPN ключи]" 
        ip xfrm state list 
        echo -e "\n" 

        echo "[ARP таблица]" 
        arp -e 2>/dev/null 
        echo -e "\n" 

        echo "[Таблица маршрутизации]" 
        ip r 2>/dev/null 
        echo -e "\n" 

        echo "[Проверка настроенных прокси]" 
        echo "$http_proxy" 
        echo -e "\n" 
        echo "$https_proxy"
        echo -e "\n" 
        env | grep proxy 
        echo -e "\n" 

        echo "[Проверяем информацию из DHCP]" 
        more /var/lib/dhclient/* 2>/dev/null | cat 
        journalctl |  grep  " lease" 
        journalctl |  grep  "DHCP" 
        echo -e "\n" 
        journalctl | grep -i dhcpd 
        echo -e "\n" 

        echo "[Сетевые процессы и сокеты с адресами]" 
        netstat -nap 2>/dev/null 
        netstat -anoptu 2>/dev/null 
        netstat -rn 2>/dev/null 
        ss -tupln 2>/dev/null 
        echo -e "\n" 

        echo "[Количество сетевых полуоткрытых соединений]" 
        netstat -tan | grep -i syn | wc -с
        netstat -tan | grep -с -i syn 2>/dev/null 
        echo -e "\n" 

        echo "[Сетевые соединения (lsof -i)]" 
        lsof -i 
        echo -e "\n" 
    } >> network_info 

    {
        echo "[Network connections list - connection]" 
        journalctl -u NetworkManager | grep -i "connection '" 
        echo -e "\n" 
        echo "[Network connections list - addresses]" 
        journalctl -u NetworkManager | grep -i "address"
        echo -e "\n" 
        echo "[Network connections wifi enabling]" 
        journalctl -u NetworkManager | grep -i wi-fi
        echo -e "\n" 
        echo "[Network connections internet]" 
        journalctl -u NetworkManager | grep -i global -A2 -B2
        echo -e "\n" 
        echo "[Подключаемые сети Wi-Fi]"  
        grep psk= /etc/NetworkManager/system-connections/* 2>/dev/null 
        echo -e "\n"
        echo "[Конфигурация firewall]"  
        firewall-cmd --list-all 2>/dev/null 
        echo -e "\n" 
        iptables -n -L -v --line-numbers 
        echo -e "\n" 
        echo "[Firewall configuration nftables]"  
        nft list ruleset 
        echo -e "\n" 
        echo "[Поиск неразборчивого режима]"  
        ip link | grep PROMISC
        echo -e "\n" 
    } >> network_add_info

    echo "[Ищем IP-адреса в текстовых файлах...]"
    for f in ${ips[@]};
    do
        echo "Search $f" 
        echo -e "\n" 
        grep -A2 -B2 -rn $f --exclude="*FULL.sh" --exclude-dir=$OUTDIR /usr /etc /var 2>/dev/null 
    done
}

process_inf_for_fedora() {
    echo -e "${cyan}[Проверка процессов, планировщиков и тд]${clear}"

    {
        echo "[Список текущих активных сессий (Screen)]"  
        screen -ls 2>/dev/null 
        echo -e "\n" 

        echo "[Фоновые задачи (jobs)]"  
        jobs 
        echo -e "\n" 

        echo "[Задачи в планировщике (Crontab)]" 
        crontab -l 2>/dev/null 
        echo -e "\n" 
    } >> process_info 

    {
        echo "[Задачи в планировщике (Crontab) в файлах /etc/cron*]" 
        more /etc/cron*/* | cat 
        echo -e "\n" 

        echo "[Вывод запланированных задач для всех юзеров (Crontab)]" 
        for user in $(ls /home/); do echo $user; crontab -u $user -l;   echo -e "\n"  ; done
        echo -e "\n" 

        echo "[Лог планировщика (Crontab) в файлах /var/log/cron.log*]" 
        more /var/log/cron.log* | cat 
        echo -e "\n" 
    } >> cronconf_info

    {
        echo "[Задачи в планировщике (Crontab) в файлах /etc/crontab]" 
        cat /etc/crontab 
        echo -e "\n" 

        echo "[Автозагрузка графических приложений (файлы с расширением .desktop)]"  
        ls -la  /etc/xdg/autostart/* 2>/dev/null   
        echo -e "\n" 

        echo "[Быстрый просмотр всех выполняемых команд через автозапуски (xdg)]"  
        cat  /etc/xdg/autostart/* | grep "Exec=" 2>/dev/null   
        echo -e "\n" 

        echo "[Автозагрузка в GNOME и KDE]"  
        more  /home/*/.config/autostart/*.desktop 2>/dev/null | cat  
        echo -e "\n" 

        echo "[Задачи из systemctl list-timers (предстоящие задачи)]" 
        systemctl list-timers 
        echo -e "\n" 

        echo "[Список процессов (ROOT)]" 
        ps -l 
        echo -e "\n" 

        echo "[Список процессов (все)]" 
        ps aux 
        ps -eaf
        echo -e "\n" 
    } >> process_info

    {
        echo "[Дерево процессов]" 
        pstree -aups
        echo -e "\n" 
    } >> pstree_file

    {
        echo "[Файлы с выводом в /dev/null]" 
        lsof -w /dev/null 
        echo -e "\n" 
    } >> lsof_file

    {
        echo "[Инфа о процессах через top]" 
        top -bcn1 -w512  
        echo -e "\n" 

        echo "[Вывод задач в бэкграунде atjobs]" 
        ls -la /var/spool/cron/atjobs 2>/dev/null 
        echo -e "\n" 

        echo "[Вывод jobs из var/spool/at/]" 
        more /var/spool/at/* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Файлы deny|allow со списками юзеров, которым разрешено в cron или jobs]" 
        more /etc/at.* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Вывод задач Anacron]" 
        more /var/spool/anacron/cron.* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Пользовательские скрипты в автозапуске rc (legacy-скрипт, который выполняется перед логоном)]" 
        more /etc/rc*/* 2>/dev/null | cat 
        more /etc/rc.d/* 2>/dev/null | cat 
        echo -e "\n" 
    } >> process_info 

    echo -e "\e[32m[Пакуем LOG-файлы (/var/log/)...]\e[0m"
    echo "[Пакуем LOG-файлы...]" >> process_info 

    tar -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null

    grep "entered promiscuous mode" /var/log/syslog
}

services_inf_for_fedora() {
    echo -e "\e[36m[Проверка сервисов в системе]\e[0m"

    {
        echo "[Список активных служб systemd]"  
        systemctl list-units  
        echo -e "\n" 

        echo "[Список всех служб]"  
        systemctl list-unit-files --type=service 
        echo -e "\n" 

        echo "[Сценарии запуска и остановки демонов (init.d)]"  
        ls -la /etc/init.d  2>/dev/null 
        echo -e "\n" 
    } >> services_info 

    {
        echo "[Вывод конфигураций всех сервисов]"  
        more /etc/systemd/system/*.service | cat 
        echo -e "\n" 
    } >> services_configs
}

devices_inf_for_fedora() {
    echo -e "${magenta}[Информация об устройствах]${clear}"
    {
        echo "[Информация об устройствах (lspci)]" 
        lspci 
        echo -e "\n" 

        echo "[Устройства USB (lsusb)]" 
        lsusb 
        echo -e "\n" 

        echo "[Блочные устройства (lsblk)]" 
        lsblk 
        echo -e "\n" 

        echo "[Список примонтированных файловых систем (findmnt)]" 
        findmnt 
        echo -e "\n" 

        echo "[Bluetooth устройства (bt-device -l)]" 
        bt-device -l 2>/dev/null 
        echo -e "\n" 

        echo "[Bluetooth устройства (hcitool dev)]" 
        hcitool dev 2>/dev/null 
        echo -e "\n" 

        echo "[Bluetooth устройства (/var/lib/bluetooth)]" 
        ls -laR /var/lib/bluetooth/ 2>/dev/null 
        echo -e "\n" 

        echo "[Устройства USB (usbrip)]" 
        usbrip events history 2>/dev/null 
        echo -e "\n" 

        echo "[Устройства USB из dmesg]" 
        dmesg | grep -i usb 2>/dev/null 
        echo -e "\n" 

        echo "[Устройства USB из journalctl]"  
        journalctl -o short-iso-precise | grep -iw usb
        echo -e "\n" 

        echo "[Устройства USB из /var/log/messages]" 
        cat /var/log/messages* | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null 
        echo -e "\n" 

        echo "[Устройства USB (dmesg)]" 
        dmesg | grep -i usb | grep -A1 -B2 -i SerialNumber: 
        echo -e "\n" 

        echo "[Устройства USB (journalctl)]" 
        journalctl | grep -i usb | grep -A1 -B2 -i SerialNumber: 
        echo -e "\n" 

        echo "[Другие устройства из journalctl]" 
        journalctl| grep -i 'PCI|ACPI|Plug' 2>/dev/null 
        echo -e "\n" 

        echo "[Подключение/отключение сетевого кабеля (адаптера) из journalctl]" 
        journalctl | grep "NIC Link is" 2>/dev/null 
        echo -e "\n" 

        echo "[LID open-downs:]"  
        journalctl | grep "Lid"  2>/dev/null  
        echo -e "\n" 
    } >> devices_info
}

env_profile_inf_for_fedora() {
    echo -e "${cyan}[Информация о переменных системы, шелле и профилях пользователей]\e[0m"
    {
        echo "[Глобальные переменные среды ОС (env)]" 
        env 
        echo -e "\n" 

        echo "[Все текущие переменные среды]" 
        printenv 
        echo -e "\n" 

        echo "[Переменные шелла]" 
        set 
        echo -e "\n" 

        echo "[Расположение исполняемых файлов доступных шеллов:]" 
        cat /etc/shells 2>/dev/null 
        echo -e "\n" 

        if [ -e "/etc/profile" ] ; then
            echo "[Содержимое из /etc/profile]" 
            cat /etc/profile 2>/dev/null 
            echo -e "\n" 
        fi
    } >> env_profile_info

    {
        echo "[Содержимое из файлов /home/users/.*]" 
        for name in $(ls /home); do
            echo Hidden config-files for: $name 
            more /home/$name/.* 2>/dev/null | cat  
            echo -e "\n" 
        done
    } >> usrs_cfgs

    {
        echo "[Содержимое скрытых конфигов рута - cat ROOT /root/.* (homie directory content + history)]" 
        more /root/.* 2>/dev/null | cat 
        echo -e "\n" 
    } >> root_cfg

    {
        echo "[Пользователи SUDO]" 
        cat /etc/sudoers 2>/dev/null 
        echo -e "\n" 
    } >> env_profile_info
}


interest_fil_for_fedora() {
    echo -e "${cyan}[Rootkits, IOCs]${clear}"
    {
        echo "[Проверка на rootkits командой chkrootkit]" 
        chkrootkit 2>/dev/null 
        echo -e "\n" 
    } >> interest_file

    echo -e "${yellow}[IOC-и файлов]${clear}"
    echo "[IOC-paths?]" >> interest_file
    echo -e "\n" >> interest_file

    counter=0
    for f in $iocfiles
    do
        if [ -e $f ]
        then 
            counter=$((counter+1))
            echo -e "${red}IOC-path found: ${clear}" $f
            echo "IOC-path found: " $f >> interest_file
            echo -e "\n" >> interest_file
        fi
    done

    if [ $counter -gt 0 ]
    then 
        echo -e "${red}IOC Markers found!!${clear}" 
        echo "IOC Markers found!!" >> interest_file
        echo -e "\n" >> interest_file
    fi

    {
        echo "[BIOS TIME]" 
        hwclock -r 2>/dev/null 
        echo -e "\n" 
        echo "[SYSTEM TIME]" 
        date 
        echo -e "\n" 

        echo "[PRIVILEGE passwd - all users]" 
        cat /etc/passwd 2>/dev/null 
        echo -e "\n" 

        echo "[Additional info cat ssh (root) keys and hosts]" 
        cat /root/.ssh/authorized_keys 2>/dev/null 
        cat /root/.ssh/known_hosts 2>/dev/null 
        echo -e "\n" 

        echo "[Additional info cat ssh (users) keys and hosts]" 
        for name in $(ls /home)
        do
            echo SSH-files for: $name 
            cat /home/$name/.ssh/authorized_keys 2>/dev/null 
            echo -e "\n" 
            cat /home/$name/.ssh/known_hosts 2>/dev/null 
        done
        echo -e "\n" 

        echo "[Virtual Machine Detection]" 
        dmidecode -s system-manufacturer 2>/dev/null 
        echo -e "\n" 
        dmidecode  2>/dev/null 
        echo -e "\n" 

        echo "[Nginx Info]" 
        echo -e "\n" 
        if [ -e "/usr/local/nginx" ] ; then
            tar -zc -f ./artifacts/HTTP_SERVER_DIR_nginx.tar.gz /usr/local/nginx 2>/dev/null
            echo "Grab NGINX files!" 
            echo -e "\n" 
        fi

        echo "[Apache Info]" 
        echo -e "\n" 
        if [ -e "/etc/httpd" ] ; then
            tar -zc -f ./artifacts/HTTP_SERVER_DIR_apache.tar.gz /etc/httpd 2>/dev/null
            echo "Grab APACHE files!" 
            echo -e "\n" 
        fi

        echo "[Core modules - lsmod]" 
        lsmod 
        echo -e "\n" 

        echo "[Пустые пароли]" 
        cat /etc/shadow | awk -F: '($2==""){print $1}' 
        echo -e "\n" 

        echo "[Malware collection]" 
        find / -name \*.bin 
        echo -e "\n" 
        find / -name \*.exe 
        echo -e "\n" 
        find /home -name \*.sh 2>/dev/null
        echo -e "\n" 
        find /home -name \*.py 2>/dev/null
        echo -e "\n" 

        echo "[NOUSER files]" 
        find /root /home -nouser 2>/dev/null 
        echo -e "\n" 

        echo "[NOGROUP files]" 
        find /root /home -nogroup 2>/dev/null 
        echo -e "\n" 
    } >> interest_file

    {
        echo "[Поиск Reverse Shell]" 
        ps aux | grep -E '(nc|netcat|ncat|socat)'
        echo -e "\n"

        echo "[Поиск java shell]"
        grep -rPl 'Runtime\.getRuntime\(\)\.exec\(|ProcessBuilder\(\)|FileOutputStream\(|FileWriter\(|URLClassLoader\(|ClassLoader\.defineClass\(|ScriptEngine\(.+\.eval\(|setSecurityManager\(null\)' /home/*/ /usr/bin /opt/application 2>/dev/null 2>/dev/null
        echo -e "\n"

        echo "[Поиск php shell]"
        grep -rPl '(?:eval\(|assert\(|base64_decode|gzinflate|\$_(GET|POST|REQUEST|COOKIE|SESSION)|passthru|shell_exec|system|[^]+`|preg_replace\s*\(.*\/e[^,]*,)' /bin /etc /home /usr  /var /dev /tmp /srv /boot /opt 2>/dev/null
        echo -e "\n"
    } >> shell_file

    {
        echo "[lsof -n]" 
        lsof -n 2>/dev/null
        echo -e "\n" 

        echo "[Verbose open files: lsof -V ]"  #open ports
        lsof -V  
        echo -e "\n" 
    } >> lsof_file

    {
        if [ -e /var/log/btmp ]
        then 
            echo "[Last LOGIN fails: lastb]" 
            lastb 2>/dev/null 
            echo -e "\n" 
        fi

        if [ -e /var/log/wtmp ]
        then 
            echo "[Login logs and reboot: last -f /var/log/wtmp]" 
            last -f /var/log/wtmp 
            echo -e "\n" 
        fi

        echo "[File system info: df -k in blocks]" 
        df -k 
        echo -e "\n" 

        echo "[File system info: df -Th in human format]" 
        df -Th 
        echo -e "\n" 

        echo "[List of mounted filesystems: mount]" 
        mount 
        echo -e "\n" 

        echo "[kernel messages: dmesg]" 
        dmesg 2>/dev/null 
        echo -e "\n" 

        echo "[Static file system info: cat /etc/fstab]"  
        cat /etc/fstab 2>/dev/null 
        echo -e "\n" 

        echo "[Virtual memory state: vmstat]"  
        vmstat 
        echo -e "\n" 

        echo "[HD devices check: dmesg | grep hd]"  
        dmesg | grep -i hd 2>/dev/null 
        echo -e "\n" 

        echo "[Get log messages: cat /var/log/messages]"  
        cat /var/log/messages 2>/dev/null 
        echo -e "\n" 

        echo "[USB check 3 Try: cat /var/log/messages]"  
        cat /var/log/messages | grep -i usb 2>/dev/null 
        echo -e "\n" 

        echo "[List all mounted files and drives: ls -lat /mnt]"  
        ls -lat /mnt 
        echo -e "\n" 

        echo "[Disk usage: du -sh]"  
        du -sh 
        echo -e "\n" 

        echo "[Disk partition info: fdisk -l]"  
        fdisk -l 2>/dev/null 
        echo -e "\n" 

        echo "[Additional info - OS version cat /proc/version]" 
        cat /proc/version 
        echo -e "\n" 

        echo "[Additional info lsb_release (distribution info)]" 
        lsb_release 2>/dev/null 
        echo -e "\n" 

        echo "[Query journal: journalctl]"  
        journalctl 
        echo -e "\n" 

        echo "[Memory free]"  
        free 
        echo -e "\n" 

        echo "[Hardware: lshw]"  
        lshw 2>/dev/null 
        echo -e "\n" 

        echo "[Hardware info: cat /proc/(cpuinfo|meminfo)]"  
        cat /proc/cpuinfo 
        echo -e "\n" 
        cat /proc/meminfo 
        echo -e "\n" 

        echo "[Get manually installed packages apt-mark showmanual (TOP)]"  
        dnf repoquery --userinstalled 2>/dev/null 
        echo -e "\n" 

        echo "[Get manually installed packages apt list --manual-installed | grep -F \[installed\]]"  
        rpm -qa --qf "%{NAME}\n"  2>/dev/null | grep -F \[installed\]  
        echo -e "\n" 

        echo "[/sbin/sysctl -a (core parameters list)]"  
        /sbin/sysctl -a 2>/dev/null 
        echo -e "\n" 

        echo "[Profile parameters: cat /etc/profile.d/*]"  
        cat /etc/profile.d/* 2>/dev/null 
        echo -e "\n" 

        echo "[Language locale]"  
        locale  2>/dev/null 
        echo -e "\n" 

        echo "[OS-release:]"  
        cat /etc/os-release 2>/dev/null  
        echo -e "\n" 

        echo "[List of boots]"  
        journalctl --list-boots  2>/dev/null  
        echo -e "\n" 

        echo "[Machine-ID:]"  
        cat /etc/machine-id 2>/dev/null 
        echo -e "\n" 

        echo "[SSL certs and keys:]"  
        ls -laR /etc/ssl    2>/dev/null  
        echo -e "\n" 

        echo "[GnuPG contains:]"  
        ls -laR /home/*/.gnupg/* 2>/dev/null  
        echo -e "\n" 
    } >> interest_file

    echo "[Web collection]"
    {
        echo "[Web collection start...]" 
        mkdir -p ./artifacts/mozilla
        cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla 

        echo "[Look through (SSH) service logs for errors]" 
        journalctl _SYSTEMD_UNIT=sshd.service | grep “error” 2>/dev/null 
        echo -e "\n" 
    } >> interest_file

    echo "Get users Recent and personalize collection" >> interest_file

    for usa in $users
    do
        mkdir -p ./artifacts/share_user/$usa
        cp -r /home/$usa/.local/share ./artifacts/share_user/$usa 2>/dev/null 
    done

    rm -r ./artifacts/share_user/$usa/Trash 2>/dev/null 
    rm -r ./artifacts/share_user/$usa/share/Trash/files 2>/dev/null 

    mkdir -p ./artifacts/share_root
    cp -r /root/.local/share ./artifacts/share_root 2>/dev/null 
    rm -r ./artifacts/share_root/Trash 2>/dev/null 
    rm -r ./artifacts/share_root/share/Trash/files 2>/dev/null 
    ls -la /home/*/.local/share/applications/ 

    mkdir -p ./artifacts/config_user
    cp -r /home/*/.config ./config_user
    for usa in $users
    do
        mkdir -p ./artifacts/config_user/$usa
        cp -r /home/$usa/.config ./artifacts/config_user/$usa 2>/dev/null 

        cp -R /home/$usa/.cache/sessions ./artifacts/config_user/$usa 2>/dev/null 
        
        {
            echo "[Mails of $usa:]" 
            cat /var/mail/$usa 2>/dev/null 
            echo -e "\n" 

            echo "[VMware clipboard]" 
            ls -laR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null 
            echo -e "\n" 
        } >> interest_file
    done
}

app_file_for_arch() {
    echo -e "${magenta}[Приложения в системе]${clear}"

    {
        echo "[Проверка браузеров]" 
        # Firefox
        firefox --version 2>/dev/null 
        # Chromium
        chromium --version 2>/dev/null 
        # Google Chrome
        google-chrome --version 2>/dev/null 
        # Opera
        opera --version 2>/dev/null 
        # Brave
        brave --version 2>/dev/null 
        # Яндекс Браузер
        yandex-browser --version 2>/dev/null 
        echo -e "\n" 

        echo "[Проверка мессенджеров и других приложений]" 
        telegram-desktop --version 2>/dev/null 
        discord --version 2>/dev/null 
        dropbox --version 2>/dev/null 
        yandex-disk --version 2>/dev/null
        echo -e "\n" 
    } >> apps_file

    {
        echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" 
        mkdir -p ./artifacts/mozilla
        cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla
        mkdir -p ./artifacts/gchrome
        cp -r /home/*/.config/google-chrome* ./artifacts/gchrome
        mkdir -p ./artifacts/chromium
        cp -r /home/*/.config/chromium ./artifacts/chromium

        echo "[Проверка приложений торрента]"  
        pacman -Q | grep torrent  
        echo -e "\n" 

        echo "[Все пакеты, установленные в системе]"  
        pacman -Q 2>/dev/null 
        echo -e "\n" 

        echo "[Запущенные процессы с удалённым исполняемым файлом]"  
        find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted 
        echo -e "\n" 
    } >> apps_file
}

users_list_for_arch() {
    echo -e "${magenta}[Пользовательские файлы]${clear}"

    # Список живых пользователей, + записываем имена в переменную для дальнейшего сбора информации
    echo "Пользователи с /home/:" 
    {
        echo "[Пользователи с /home/:]"  
        ls /home 
        # Исключаем папку lost+found
        users=$(ls /home -I lost\*)
        echo $users
        echo -e "\n" 

        echo "[Текущие авторизированные пользователи:" 
        w 
        echo -e "\n" 
    } >> users_file

    {
        echo "[Текущий пользователь:]" 
        who am i 
        echo -e "\n" 

        echo "[Информация об учетных записях и группах]"
        for name in $(ls /home); do
            id $name  
        done
        echo -e "\n" 

        # Поиск новых учетных записей в /etc/passwd
        echo "[Поиск новых учетных записей]" 
        sort -nk3 -t: /etc/passwd | less
        echo -e "\n" 
        egrep ':0+: ' /etc/passwd
        echo -e "\n" 

        echo "[Использование нескольких методов аутентификации]" 
        getent passwd | egrep ':0+: '
        echo -e "\n" 

        # Вывод файлов, которые могут указывать на то, что временная учетная запись злоумышленника была удалена
        echo "[Временная учетная запись злоумышленника была удалена]" 
        find / -nouser -print
        echo -e "\n" 

        echo "[Пользовательские файлы из (Downloads, Documents, Desktop)]" 
        ls -la /home/*/Downloads 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Загрузки 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Documents 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Документы 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Desktop/ 2>/dev/null 
        echo -e "\n" 
        ls -la /home/*/Рабочий\ стол/ 2>/dev/null 
        echo -e "\n" 

        # Составляем список файлов в корзине
        echo "[Файлы в корзине из home]" 
        ls -laR /home/*/.local/share/Trash/files 2>/dev/null 
        echo -e "\n" 

        # Для рута тоже на всякий случай
        echo "[Файлы в корзине из root]" 
        ls -laR /root/.local/share/Trash/files 2>/dev/null 
        echo -e "\n" 

        # Кешированные изображения могут помочь понять, какие программы использовались
        echo "[Кешированные изображения программ из home]" 
        ls -la /home/*/.thumbnails/ 2>/dev/null 
        echo -e "\n" 
    } >> users_file
    
    {
        echo "[Поиск уникальных файловых расширений в папках home и root:]" >> users_file
        find /root /home -type f -name \*.exe -o -name \*.jpg -o -name \*.bmp -o -name \*.png -o -name \*.doc -o -name \*.docx -o -name \*.xls -o -name \*.xlsx -o -name \*.csv -o -name \*.odt -o -name \*.ppt -o -name \*.pptx -o -name \*.ods -o -name \*.odp -o -name \*.tif -o -name \*.tiff -o -name \*.jpeg -o -name \*.mbox -o -name \*.eml 2>/dev/null >> users_file
        echo -e "\n"
    } >> users_file

    # Ищем логи приложений (но не в /var/log)
    {
        echo "[Возможные логи приложений (с именем или расширением *log*)]"
        find /root /home /bin /etc /lib64 /opt /run /usr -type f -name \*log* 2>/dev/null
    } >> change_files

    echo "[Таймлайн файлов в домашних каталогах (CSV)]"
    {
        echo "file_location_and_name, date_last_Accessed, date_last_Modified, date_last_status_Change, owner_Username, owner_Groupname,sym_permissions, file_size_in_bytes, num_permissions" 
        echo -n 
        find /home /root -type f -printf "%p,%A+,%T+,%C+,%u,%g,%M,%s,%m\n" 2>/dev/null 
    } >> users_file_timeline
}

app_file_for_arch() {
    echo -e "${magenta}[Приложения в системе]${clear}"

    {
        echo "[Проверка браузеров]" 
        # Firefox
        firefox --version 2>/dev/null 
        # Chromium
        chromium --version 2>/dev/null 
        # Google Chrome
        google-chrome --version 2>/dev/null 
        # Opera
        opera --version 2>/dev/null 
        # Brave
        brave --version 2>/dev/null 
        # Яндекс Браузер
        yandex-browser --version 2>/dev/null 
        echo -e "\n" 

        echo "[Проверка мессенджеров и других приложений]" 
        telegram-desktop --version 2>/dev/null 
        discord --version 2>/dev/null 
        dropbox --version 2>/dev/null 
        yandex-disk --version 2>/dev/null
        echo -e "\n" 
    } >> apps_file

    {
        echo "[Сохранение профилей популярных браузеров в папку ./artifacts]" 
        mkdir -p ./artifacts/mozilla
        cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla
        mkdir -p ./artifacts/gchrome
        cp -r /home/*/.config/google-chrome* ./artifacts/gchrome
        mkdir -p ./artifacts/chromium
        cp -r /home/*/.config/chromium ./artifacts/chromium

        echo "[Проверка приложений торрента]"  
        pacman -Q | grep torrent  
        echo -e "\n" 

        echo "[Все пакеты, установленные в системе]"  
        pacman -Q 2>/dev/null 
        echo -e "\n" 

        echo "[Запущенные процессы с удалённым исполняемым файлом]"  
        find /proc -name exe ! -path "*/task/*" -ls 2>/dev/null | grep deleted 
        echo -e "\n" 
    } >> apps_file
}

history_inf_for_arch() {
    echo -e "${yellow}[Информация по истории]${clear}"
    {
        # Текущее время работы системы, количество залогиненных пользователей
        echo "[Время работы системы, количество залогиненных пользователей]" 
        uptime 
        echo -e "\n" 

        echo "[Журнал перезагрузок (last -x reboot)]" 
        last -x reboot 
        echo -e "\n" 

        echo "[Журнал выключений (last -x shutdown)]" 
        last -x shutdown 
        echo -e "\n" 

        # Список последних входов в систему с указанием даты (/var/log/lastlog)
        echo "[Список последних входов в систему (/var/log/lastlog)]" 
        lastlog 
        echo -e "\n" 

        # Список последних залогиненных юзеров (/var/log/wtmp), их сессий, ребутов и включений и выключений
        echo "[Список последних залогиненных юзеров с деталями (/var/log/wtmp)]" 
        last -Faiwx 
        echo -e "\n" 

        echo "[Последние команды из fc текущего пользователя]" 
        history -a 1 2>/dev/null 
        echo -e "\n" 

        if ls /root/.*_history >/dev/null 2>&1; then
            echo "[История root-а (/root/.*history)]" 
            more /root/.*history | cat 
            echo -e "\n" 
        fi

        for name in $(ls /home); do
            echo "[История пользоватея ${name} (.*history)]" 
            more /home/$name/.*history 2>/dev/null | cat    
            echo -e "\n" 
            echo "[История команд Python пользоватея ${name}]" 
            more /home/$name/.python_history 2>/dev/null | cat 
            echo -e "\n" 
        done

        # Arch Linux использует pacman для управления пакетами
        echo "[История установленных приложений]" 
        journalctl -u pacman | grep "installed" 
        echo -e "\n" 

        echo "[История обновленных приложений]" 
        journalctl -u pacman | grep "upgraded"  
        echo -e "\n" 

        echo "[История удаленных приложений]" 
        journalctl -u pacman | grep "removed"  
        echo -e "\n" 

        # Arch Linux не использует apt, поэтому этот раздел не нужен
        # echo "[История о последних apt-действиях (history.log)]" 
        # cat /var/log/apt/history.log 
        # echo -e "\n" 
    } >> history_info 
}

network_inf_for_arch() {
    echo -e "${blue}[Проверка сетевой информации]${clear}"

    {
        # Информация о сетевых адаптерах
        echo "[IP адрес(а):]" 
        ip l 
        echo -e "\n" 

        echo "[Настройки сети]" 
        ip addr show 
        echo -e "\n" 

        echo "[Сетевые интерфейсы (конфиги)]" 
        cat /etc/netctl/* 2>/dev/null 
        echo -e "\n" 

        echo "[Настройки DNS]" 
        cat /etc/resolv.conf 
        cat /etc/host.conf    2>/dev/null 
        echo -e "\n" 

        echo "[Сетевой менеджер (nmcli)]" 
        nmcli 
        echo -e "\n" 

        echo "[Беспроводные сети (iwconfig)]" 
        iwconfig 2>/dev/null 
        echo -e "\n" 

        echo "[Информация из hosts (local DNS)]" 
        cat /etc/hosts 
        echo -e "\n" 

        echo "[Сетевое имя машины (hostname)]" 
        cat /etc/hostname 
        echo -e "\n" 

        echo "[Сохраненные VPN ключи]" 
        ip xfrm state list 
        echo -e "\n" 

        echo "[ARP таблица]" 
        ip neigh 
        echo -e "\n" 

        echo "[Таблица маршрутизации]" 
        ip r 
        echo -e "\n" 

        echo "[Проверка настроенных прокси]" 
        echo "$http_proxy" 
        echo -e "\n" 
        echo "$https_proxy"
        echo -e "\n" 
        env | grep proxy 
        echo -e "\n" 

        # База аренд DHCP-сервера (файлы dhcpd.leases)
        echo "[Проверяем информацию из DHCP]" 
        more /var/lib/dhcpcd/* 2>/dev/null | cat 
        # Информация о назначенном адресе по DHCP
        journalctl |  grep  " lease" 
        # При установленном NetworkManager
        journalctl |  grep  "DHCP" 
        echo -e "\n" 
        # Информация о DHCP-действиях на хосте
        journalctl | grep -i dhcpd 
        echo -e "\n" 

        echo "[Сетевые процессы и сокеты с адресами]" 
        # Активные сетевые процессы и сокеты с адресами
        netstat -nap 2>/dev/null 
        netstat -anoptu 2>/dev/null 
        netstat -rn 2>/dev/null 
        # Вывод имен процессов с текущими TCP/UDP-соединениями (только под рутом)
        ss -tupln 2>/dev/null 
        echo -e "\n" 

        echo "[Количество сетевых полуоткрытых соединений]" 
        netstat -tan | grep -i syn | wc -с
        netstat -tan | grep -с -i syn 2>/dev/null 
        echo -e "\n" 

        echo "[Сетевые соединения (lsof -i)]" 
        lsof -i 
        echo -e "\n" 
    } >> network_info 

    {
        echo "[Network connections list - connection]" 
        journalctl -u NetworkManager | grep -i "connection '" 
        echo -e "\n" 
        echo "[Network connections list - addresses]" 
        journalctl -u NetworkManager | grep -i "address"

        echo -e "\n" 
        echo "[Network connections wifi enabling]" 
        journalctl -u NetworkManager | grep -i wi-fi
        echo -e "\n" 

        echo "[Network connections internet]" 
        journalctl -u NetworkManager | grep -i global -A2 -B2
        echo -e "\n" 

        echo "[Подключаемые сети Wi-Fi]"  
        grep psk= /etc/NetworkManager/system-connections/* 2>/dev/null 
        echo -e "\n"

        echo "[Конфигурация firewall]"  
        iptables-save 2>/dev/null 
        echo -e "\n" 
        iptables -n -L -v --line-numbers 
        echo -e "\n" 

        # Список правил файрвола nftables
        echo "[Firewall configuration nftables]"  
        nft list ruleset 
        echo -e "\n" 

        echo "[Поиск неразборчивого режима]"  
        ip link | grep PROMISC
        echo -e "\n" 
    } >> network_add_info

    # Ищем IP-адреса в логах и выводим список
    #echo "[Ищем IP-адреса в текстовых файлах...]"
    #for f in ${ips[@]};
    #do
    #    echo "Search $f" 
    #    echo -e "\n" 
    #    grep -A2 -B2 -rn $f --exclude="*FULL.sh" --exclude-dir=$OUTDIR /usr /etc /var 2>/dev/null 
    #done
}

process_inf_for_arch() {
    echo -e "${magenta}[Проверка процессов, планировщиков и тд]${clear}"

    {
        echo "[Список текущих активных сессий (Screen)]"  
        screen -ls 2>/dev/null 
        echo -e "\n" 

        echo "[Фоновые задачи (jobs)]"  
        jobs 
        echo -e "\n" 

        echo "[Задачи в планировщике (Crontab)]" 
        crontab -l 2>/dev/null 
        echo -e "\n" 
    } >> process_info 

    {
        echo "[Задачи в планировщике (Crontab) в файлах /etc/cron*]" 
        more /etc/cron*/* | cat 
        echo -e "\n" 

        echo "[Вывод запланированных задач для всех юзеров (Crontab)]" 
        for user in $(ls /home/); do echo $user; crontab -u $user -l;   echo -e "\n"  ; done
        echo -e "\n" 

        echo "[Лог планировщика (Crontab) в файлах /var/log/cron*]" 
        more /var/log/cron* | cat 
        echo -e "\n" 
    } >> cronconf_info

    {
        echo "[Задачи в планировщике (Crontab) в файлах /etc/crontab]" 
        cat /etc/crontab 
        echo -e "\n" 

        echo "[Автозагрузка графических приложений (файлы с расширением .desktop)]"  
        ls -la  /etc/xdg/autostart/* 2>/dev/null   
        echo -e "\n" 

        echo "[Быстрый просмотр всех выполняемых команд через автозапуски (xdg)]"  
        cat  /etc/xdg/autostart/* | grep "Exec=" 2>/dev/null   
        echo -e "\n" 

        echo "[Автозагрузка в GNOME и KDE]"  
        more  /home/*/.config/autostart/*.desktop 2>/dev/null | cat  
        echo -e "\n" 

        echo "[Задачи из systemctl list-timers (предстоящие задачи)]" >> system_file
        systemctl list-timers 
        echo -e "\n" 

        echo "[Список процессов (ROOT)]" 
        ps -l 
        echo -e "\n" 

        echo "[Список процессов (все)]" 
        ps aux 
        ps -eaf
        echo -e "\n" 

        # Удалено, так как chkconfig не используется в Arch Linux
        #echo "[Список всех доступных служб и их обновлений]" 
        #chkconfig –list
        #echo -e "\n"
    } >> process_info

    {
        echo "[Дерево процессов]" 
        pstree -aups
        echo -e "\n" 
    } >> pstree_file

    {
        echo "[Файлы с выводом в /dev/null]" 
        lsof -w /dev/null 
        echo -e "\n" 
    } >> lsof_file

    {
        # Текстовый вывод аналога виндового диспетчера задач
        echo "[Инфа о процессах через top]" 
        top -bcn1 -w512  
        echo -e "\n" 

        echo "[Вывод задач в бэкграунде atjobs]" 
        ls -la /var/spool/cron/atjobs 2>/dev/null 
        echo -e "\n" 

        echo "[Вывод jobs из var/spool/at/]" 
        more /var/spool/at/* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Файлы deny|allow со списками юзеров, которым разрешено в cron или jobs]" 
        more /etc/at.* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Вывод задач Anacron]" 
        more /var/spool/anacron/cron.* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Пользовательские скрипты в автозапуске rc (legacy-скрипт, который выполняется перед логоном)]" 
        more /etc/rc*/* 2>/dev/null | cat 
        more /etc/rc.d/* 2>/dev/null | cat 
        echo -e "\n" 
    } >> process_info 

    echo -e "${green}[Пакуем LOG-файлы (/var/log/)...]${clear}"
    echo "[Пакуем LOG-файлы...]" >> process_info 


    # /var/log/
    tar -zc -f ./artifacts/VAR_LOG.tar.gz /var/log/ 2>/dev/null

    #/var/log/auth.log Аутентификация
    #/var/log/cron.log Cron задачи
    #/ var / log / maillog Почта
    #/ var / log / httpd Apache
    # Подробнее: https://www.securitylab.ru/analytics/520469.php

    grep "entered promiscuous mode" /var/log/syslog
}

services_inf_for_arch() {
echo -e "${cyan}[Проверка сервисов в системе]${clear}"

    {
    echo "[Список активных служб systemd]"  
    systemctl list-units  
    echo -e "\n" 

    echo "[Список всех служб]"  
    
    systemctl list-unit-files --type=service --all
    echo -e "\n" 

    } >> services_info 

    {
    echo "[Вывод конфигураций всех сервисов]"  
    more /etc/systemd/system/*.service | cat 
    echo -e "\n" 
    } >> services_configs

    {
    
    echo "[Список запускаемых сервисов]"  
    ls -la /etc/systemd/system/ 2>/dev/null 
    echo -e "\n" 

    echo "[Сценарии запуска и остановки демонов]"  
    ls -la /etc/init.d  2>/dev/null 
    echo -e "\n" 
    } >> services_info
}

devices_inf_for_arch() {
    echo -e "${magenta}[Информация об устройствах]${clear}"
    {
        echo "[Информация об устройствах (lspci)]" 
        lspci 
        echo -e "\n" 

        echo "[Устройства USB (lsusb)]" 
        lsusb 
        echo -e "\n" 

        echo "[Блочные устройства (lsblk)]" 
        lsblk 
        echo -e "\n" 
        more /sys/bus/pci/devices/*/* 2>/dev/null | cat 
        echo -e "\n" 

        echo "[Список примонтированных файловых систем (findmnt)]" 
        findmnt 
        echo -e "\n" 

        # Удалено, так как bt-device и hcitool не установлены по умолчанию
        #echo "[Bluetooth устройства (bt-device -l)]" 
        #bt-device -l 2>/dev/null 
        #echo -e "\n" 

        #echo "[Bluetooth устройства (hcitool dev)]" 
        #hcitool dev 2>/dev/null 
        #echo -e "\n" 

        echo "[Bluetooth устройства (/var/lib/bluetooth)]" 
        ls -laR /var/lib/bluetooth/ 2>/dev/null 
        echo -e "\n" 

        # Удалено, так как usbrip не установлен по умолчанию
        #echo "[Устройства USB (usbrip)]" 
        #usbrip events history 2>/dev/null 
        #echo -e "\n" 

        echo "[Устройства USB из dmesg]" 
        dmesg | grep -i usb 2>/dev/null 
        echo -e "\n" 

        echo "[Устройства USB из journalctl]"  
        journalctl -o short-iso-precise | grep -iw usb
        echo -e "\n" 

        # Удалено, так как syslog не используется в Arch Linux
        #echo "[Устройства USB из syslog]" 
        #cat /var/log/syslog* | grep -i usb | grep -A1 -B2 -i SerialNumber: 
        #echo -e "\n" 

        # Удалено, так как messages не используется в Arch Linux
        #echo "[Устройства USB из (log messages)]" 
        #cat /var/log/messages* | grep -i usb | grep -A1 -B2 -i SerialNumber: 2>/dev/null 
        #echo -e "\n" 

        echo "[Устройства USB (dmesg)]" 
        dmesg | grep -i usb | grep -A1 -B2 -i SerialNumber: 
        echo -e "\n" 
        echo "[Устройства USB (journalctl)]" 
        journalctl | grep -i usb | grep -A1 -B2 -i SerialNumber: 
        echo -e "\n" 

        echo "[Другие устройства из journalctl]" 
        journalctl| grep -i 'PCI|ACPI|Plug' 2>/dev/null 
        echo -e "\n" 

        echo "[Подключение/отключение сетевого кабеля (адаптера) из journalctl]" 
        journalctl | grep "NIC Link is" 2>/dev/null 
        echo -e "\n" 

        # Открытие/закрытие крышки ноутбука
        echo "[LID open-downs:]"  
        journalctl | grep "Lid"  2>/dev/null  
        echo -e "\n" 
        } >> devices_info
}

env_profile_inf_for_arch() {
    echo -e "${cyan}[Информация о переменных системы, шелле и профилях пользователей]${clear}"
    {
        echo "[Глобальные переменные среды ОС (env)]" 
        env 
        echo -e "\n" 

        echo "[Все текущие переменные среды]" 
        printenv 
        echo -e "\n" 

        echo "[Переменные шелла]" 
        set 
        echo -e "\n" 

        echo "[Расположение исполняемых файлов доступных шеллов:]" 
        cat /etc/shells 2>/dev/null 
        echo -e "\n" 

        if [ -e "/etc/profile" ] ; then
            echo "[Содержимое из /etc/profile]" 
            cat /etc/profile 2>/dev/null 
            echo -e "\n" 
        fi
    } >> env_profile_info

    {
        echo "[Содержимое из файлов /home/users/.*]" 
        for name in $(ls /home); do
            echo Hidden config-files for: $name 
            more /home/$name/.* 2>/dev/null | cat  
            echo -e "\n" 
        done
    } >> usrs_cfgs

    {
        echo "[Содержимое скрытых конфигов рута - cat ROOT /root/.* (homie directory content + history)]" 
        more /root/.* 2>/dev/null | cat 
        echo -e "\n" 
    } >> root_cfg

    # Список файлов, пример
    #.*_profile (.profile)
    #.*_login
    #.*_logout
    #.*rc
    #.*history 
    {
        echo "[Пользователи SUDO]" 
        cat /etc/sudoers 2>/dev/null 
        echo -e "\n" 
    } >> env_profile_info
}

interest_fil_for_arch() {
    echo -e "${cyan}[Rootkits, IOCs]${clear}"
    {
        # Проверимся на руткиты
        echo "[Проверка на rootkits командой chkrootkit]" 
        chkrootkit 2>/dev/null 
        echo -e "\n" 
    } >> interest_file

    echo -e "${yellow}[IOC-и файлов]${clear}"
    echo "[IOC-paths?]" >> interest_file
    echo -e "\n" >> interest_file

    counter=0;
    for f in $iocfiles
        do
            if [ -e $f ] ; then 
                counter=$((counter+1))
                echo -e "${red}IOC-path found: ${clear}" $f
                echo "IOC-path found: " $f >> interest_file
                echo -e "\n" >> interest_file
            fi
        done

    if [ $counter -gt 0 ] ; then 
        echo -e "${red}IOC Markers found!!${clear}" 
        echo "IOC Markers found!!" >> interest_file
        echo -e "\n" >> interest_file
    fi

    {
        echo "[BIOS TIME]" 
        hwclock -r 2>/dev/null 
        echo -e "\n" 
        echo "[SYSTEM TIME]" 
        date 
        echo -e "\n" 

        # privilege information
        echo "[PRIVILEGE passwd - all users]" 
        cat /etc/passwd 2>/dev/null 
        echo -e "\n" 

        # ssh keys
        echo "[Additional info cat ssh (root) keys and hosts]" 
        cat /root/.ssh/authorized_keys 2>/dev/null 
        cat /root/.ssh/known_hosts 2>/dev/null 
        echo -e "\n" 

        #for users:
        echo "[Additional info cat ssh (users) keys and hosts]" 
        for name in $(ls /home)
            do
                echo SSH-files for: $name 
                cat /home/$name/.ssh/authorized_keys 2>/dev/null 
                echo -e "\n" 
                cat /home/$name/.ssh/known_hosts 2>/dev/null 
            done
        echo -e "\n" 

        # VM - detection
        echo "[Virtual Machine Detection]" 
        dmidecode -s system-manufacturer 2>/dev/null 
        echo -e "\n" 
        dmidecode  2>/dev/null 
        echo -e "\n" 

        # HTTP server inforamtion collection
        # Nginx collection
        echo "[Nginx Info]" 
        echo -e "\n" 
        # tar default directory
        if [ -e "/usr/local/nginx" ] ; then
            tar -zc -f ./artifacts/HTTP_SERVER_DIR_nginx.tar.gz /usr/local/nginx 2>/dev/null
            echo "Grab NGINX files!" 
            echo -e "\n" 
        fi

        # Apache2 collection
        echo "[Apache Info]" 
        echo -e "\n" 
        # tar default directory
        if [ -e "/etc/apache2" ] ; then
            tar -zc -f ./artifacts/HTTP_SERVER_DIR_apache.tar.gz /etc/apache2 2>/dev/null
            echo "Grab APACHE files!" 
            echo -e "\n" 
        fi

        # Install files
        echo "[Core modules - lsmod]" 
        lsmod 
        echo -e "\n" 

        echo "[Пустые пароли]" 
        cat /etc/shadow | awk -F: '($2==""){print $1}' 
        echo -e "\n" 

        # .bin
        echo "[Malware collection]" 

        find / -name \*.bin 
        echo -e "\n" 

        find / -name \*.exe 
        echo -e "\n" 

        find /home -name \*.sh 2>/dev/null
        echo -e "\n" 

        find /home -name \*.py 2>/dev/null
        echo -e "\n" 

        #find copied
        # Find nouser or nogroup  data
        echo "[NOUSER files]" 
        find /root /home -nouser 2>/dev/null 
        echo -e "\n" 

        echo "[NOGROUP files]" 
        find /root /home -nogroup 2>/dev/null 
        echo -e "\n" 

    } >> interest_file

    {
        # Поиск всех процессов, у которых в командной строке встречается строка "nc" или "netcat"
        echo "[Поиск Reverse Shell]" 
        ps aux | grep -E '(nc|netcat|ncat|socat)'
        echo -e "\n"

        #попытка шелла на java
        echo "[Поиск java shell]"
        grep -rPl 'Runtime\.getRuntime\(\)\.exec\(|ProcessBuilder\(\)|FileOutputStream\(|FileWriter\(|URLClassLoader\(|ClassLoader\.defineClass\(|ScriptEngine\(.+\.eval\(|setSecurityManager\(null\)' /home/*/ /usr/bin /opt/application 2>/dev/null 2>/dev/null
        echo -e "\n"

        #поиск шелла на php
        echo "[Поиск php shell]"
        grep -rPl '(?:eval\(|assert\(|base64_decode|gzinflate|\$_(GET|POST|REQUEST|COOKIE|SESSION)|passthru|shell_exec|system|[^]+`|preg_replace\s*\(.*\/e[^,]*,)' /bin /etc /home /usr  /var /dev /tmp /srv /boot /opt 2>/dev/null
        echo -e "\n"
    } >> shell_file

    {
        echo "[lsof -n]" 
        lsof -n 2>/dev/null
        echo -e "\n" 

        echo "[Verbose open files: lsof -V ]"  #open ports
        lsof -V  
        echo -e "\n" 
    } >> lsof_file

    {
        if [ -e /var/log/btmp ]
            then 
            echo "[Last LOGIN fails: lastb]" 
            lastb 2>/dev/null 
            echo -e "\n" 
        fi

        if [ -e /var/log/wtmp ]
            then 
            echo "[Login logs and reboot: last -f /var/log/wtmp]" 
            last -f /var/log/wtmp 
            echo -e "\n" 
        fi

        # Удалено, так как inetd.conf не используется в Arch Linux
        #if [ -e /etc/inetd.conf ]
        #then
        #	echo "[inetd.conf]" 
        #	cat /etc/inetd.conf 
        #	echo -e "\n" 
        #fi

        echo "[File system info: df -k in blocks]" 
        df -k 
        echo -e "\n" 

        echo "[File system info: df -Th in human format]" 
        df -Th 
        echo -e "\n" 

        echo "[List of mounted filesystems: mount]" 
        mount 
        echo -e "\n" 

        echo "[kernel messages: dmesg]" 
        dmesg 2>/dev/null 
        echo -e "\n" 

        # Удалено, так как sources.list не используется в Arch Linux
        #echo "[Repo info: cat /etc/apt/sources.list]"  
        #cat /etc/apt/sources.list 
        #echo -e "\n" 

        echo "[Static file system info: cat /etc/fstab]"  
        cat /etc/fstab 2>/dev/null 
        echo -e "\n" 

        echo "[Virtual memory state: vmstat]"  
        vmstat 
        echo -e "\n" 

        echo "[HD devices check: dmesg | grep hd]"  
        dmesg | grep -i hd 2>/dev/null 
        echo -e "\n" 

        # Удалено, так как messages не используется в Arch Linux
        #echo "[Get log messages: cat /var/log/messages]"  
        #cat /var/log/messages 2>/dev/null 
        #echo -e "\n" 

        # Удалено, так как messages не используется в Arch Linux
        #echo "[USB check 3 Try: cat /var/log/messages]"  
        #cat /var/log/messages | grep -i usb 2>/dev/null 
        #echo -e "\n" 

        echo "[List all mounted files and drives: ls -lat /mnt]"  
        ls -lat /mnt 
        echo -e "\n" 

        echo "[Disk usage: du -sh]"  
        du -sh 
        echo -e "\n" 

        echo "[Disk partition info: fdisk -l]"  
        fdisk -l 2>/dev/null 
        echo -e "\n" 

        echo "[Additional info - OS version cat /proc/version]" 
        cat /proc/version 
        echo -e "\n" 

        echo "[Additional info lsb_release (distribution info)]" 
        lsb_release 2>/dev/null 
        echo -e "\n" 

        echo "[Query journal: journalctl]"  
        journalctl 
        echo -e "\n" 

        echo "[Memory free]"  
        free 
        echo -e "\n" 

        echo "[Hardware: lshw]"  
        lshw 2>/dev/null 
        echo -e "\n" 

        echo "[Hardware info: cat /proc/(cpuinfo|meminfo)]"  
        cat /proc/cpuinfo 
        echo -e "\n" 
        cat /proc/meminfo 
        echo -e "\n" 

        echo "[/sbin/sysctl -a (core parameters list)]"  
        /sbin/sysctl -a 2>/dev/null 
        echo -e "\n" 

        echo "[Profile parameters: cat /etc/profile.d/*]"  
        cat /etc/profile.d/* 2>/dev/null 
        echo -e "\n" 

        echo "[Language locale]"  
        locale  2>/dev/null 
        echo -e "\n" 

        echo "[Get manually installed packages (pacman -Qe)]"  
        pacman -Qe 2>/dev/null 
        echo -e "\n"  

        mkdir -p ./artifacts/config_root
        #desktop icons and other_stuff
        cp -r /root/.config ./artifacts/config_root 2>/dev/null 
        #saved desktop sessions of users
        cp -R /root/.cache/sessions ./artifacts/config_root 2>/dev/null 

        echo "[VMware clipboard (root)!]" 
        ls -laR /root/.cache/vmware/drag_and_drop/ 2>/dev/null 
        echo -e "\n" 

        echo "[Mails of root]" 
        cat /var/mail/root 2>/dev/null 
        echo -e "\n" 

        cp -R ~/.config/ 2>/dev/null 

        echo "[Apps ls -la /usr/share/applications]"  
        ls -la /usr/share/applications 
        ls -la /home/*/.local/share/applications/ 
        echo -e "\n" 

        #recent 
        echo "[Recently-Used]"  
        more  /home/*/.local/share/recently-used.xbel 2>/dev/null | cat 
        echo -e "\n"  

        echo "[Var-LIBS directories - like program list]"  
        ls -la /var/lib 2>/dev/null  
        echo -e "\n" 

        echo "[Some encypted data?]"  
        cat /etc/crypttab 2>/dev/null  
        echo -e "\n" 

        echo "[User dirs default configs]"  
        cat /etc/xdg/user-dirs.defaults  2>/dev/null  
        echo -e "\n"       

        echo "[OS-release:]"  
        cat /etc/os-release 2>/dev/null  
        echo -e "\n" 

        echo "[List of boots]"  
        journalctl --list-boots  2>/dev/null  
        echo -e "\n" 

        echo "[Machine-ID:]"  
        cat /etc/machine-id 2>/dev/null 
        echo -e "\n" 

        echo "[SSL certs and keys:]"  
        ls -laR /etc/ssl    2>/dev/null  
        echo -e "\n" 

        echo "[GnuPG contains:]"  
        ls -laR /home/*/.gnupg/* 2>/dev/null  
        echo -e "\n" 

    } >> interest_file

    echo "[Web collection]"
    {
        echo "[Web collection start...]" 
        mkdir -p ./artifacts/mozilla
        cp -r /home/*/.mozilla/firefox/ ./artifacts/mozilla 

        echo "[Look through (SSH) service logs for errors]" 
        journalctl _SYSTEMD_UNIT=sshd.service | grep “error” 2>/dev/null 
        echo -e "\n" 
    } >> interest_file

    echo "Get users Recent and personalize collection" >> interest_file

    for usa in $users
    do
        mkdir -p ./artifacts/share_user/$usa
        cp -r /home/$usa/.local/share ./artifacts/share_user/$usa 2>/dev/null 
    done

    rm -r ./artifacts/share_user/$usa/Trash 2>/dev/null 
    rm -r ./artifacts/share_user/$usa/share/Trash/files 2>/dev/null 

    mkdir -p ./artifacts/share_root
    cp -r /root/.local/share ./artifacts/share_root 2>/dev/null 
    rm -r ./artifacts/share_root/Trash 2>/dev/null 
    rm -r ./artifacts/share_root/share/Trash/files 2>/dev/null 
    ls -la /home/*/.local/share/applications/ 

    mkdir -p ./artifacts/config_user
    cp -r /home/*/.config ./config_user
    for usa in $users
        do
            mkdir -p ./artifacts/config_user/$usa
            #desktop icons and other_stuff
            cp -r /home/$usa/.config ./artifacts/config_user/$usa 2>/dev/null 

            #saved desktop sessions of users
            cp -R /home/$usa/.cache/sessions ./artifacts/config_user/$usa 2>/dev/null 

        {
            #check mail:
            echo "[Mails of $usa:]" 
            cat /var/mail/$usa 2>/dev/null 
            echo -e "\n" 

            echo "[VMware clipboard]" 
            ls -laR /home/$usa/.cache/vmware/drag_and_drop/ 2>/dev/null 
            echo -e "\n" 
        } >> interest_file
    done
}

mitre_ioc_for_arch() {
#detect log4j
    {
        Initial_Access()
        {
            echo "[Detect log4j IOC]"
            printf "| %-40s |\n" "`date`"
        }

        Initial_Access
        sleep 2
        echo "[Initial_Access]"
        echo "[Поиск попыток эксплуатации в файлах по пути /var/log]"
        sudo egrep -I -i -r '\$(\{|%7B)jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):/[^\n]+' /var/log
        echo -e "\n" 

        sudo find /var/log -name \*.gz -print0 | xargs -0 zgrep -E -i '\$(\{|%7B)jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):/[^\n]+'
        echo -e "\n" 

        echo "[Поиск обфусцированных вариантов]"
        sudo find /var/log/ -type f -exec sh -c "cat {} | sudo sed -e 's/\${lower://'g | tr -d '}' | sudo egrep -I -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \;
        echo -e "\n" 
        sudo find /var/log/ -name '*.gz' -type f -exec sh -c "zcat {} | sudo sed -e 's/\${lower://'g | tr -d '}' | sudo egrep -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \;
        echo -e "\n" 

        # Удалено, так как Execution не определено
        # Execution

    } >> mitre_ioc_file
}

# Выполнение задач в зависимости от операционной системы
case $OS_LIKE in
    "debian")
        echo "Это "$OS_NAME"."
        # задачи для ос на базе дебиан
		debian() {
			host_data 
			users_list
			app_file
			virt_apps
			history_inf
			{
			    network_inf
			    process_inf
			    services_inf
			    devices_inf
			    env_profile_inf
			    interest_fil
			    mitre_ioc
			    archive
			    change_rights
			} |& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log)
		}
		debian
		
        ;;
    "fedora"|"rhel"|"centos")
        echo "Это" $OS_NAME"."
        fedora(){
            host_data
            user_list_for_fedora
            app_file_for_fedora
            virt_apps_for_fedora
            history_inf_for_fedora
            {
                network_inf_for_fedora
                process_inf_for_fedora
                services_inf_for_fedora
                devices_inf_for_fedora
                env_profile_inf_for_fedora
                interest_fil_for_fedora
                mitre_ioc_for_fedora
                archive
                change_rights
            }|& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log)
        }
        fedora
         
        ;;
    "arch")
        echo "Это" $OS_NAME"."
        arch(){
            host_data
            users_list_for_arch
            app_file_for_arch
            virt_apps
            history_inf_for_arch
            {
                network_inf_for_arch
                process_inf_for_arch
                services_inf_for_arch
                devices_inf_for_arch
                env_profile_inf_for_arch
                interest_fil_for_arch
                mitre_ioc_for_arch
                archive
                change_files
            }|& tee >(sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" >> ./console_log)
        }
        arch
        
        ;;
    "Oracle Linux")
        echo "Это Oracle Linux."
        
        ;;
    *)
        echo "Неизвестная операционная система: $OS"

	
        ;;
esac
