# PROD

Use this command to deploy the domain project into the production environment:

```bash
CRED='\033[0;31m' && CYELLOW='\033[0;33m' && CDEF='\033[0m' \
  && echo -e "\n${CRED}Before starting, if the domain is already installed do the following:${CDEF}" \
  && echo -e "${CRED}  * Backup the DB to Cloudflare R2${CDEF}" \
  && echo -e "${CRED}  * Backup .env.local${CDEF}" \
  && echo -e "${CRED}  * Backup .envs/.docker/.env.local${CDEF}" \
  && echo -e "${CRED}  * Backup /etc/php/8.4/fpm/pool.d/www.conf${CDEF}" \
  && echo -e "${CRED}  * Backup /etc/postgresql/17/main/postgresql.conf${CDEF}\n" \
  && R=$(TZ=Europe/Bucharest date +%Y-%m-%d_%H-%M-%S)_$(shuf -i 10000-99000 -n 1) \
  && mkdir "/tmp/$R/" \
  && cd "/tmp/$R" \
  && read -e -p "$(echo -e \\\n${CYELLOW}Git branch \(to pull the project and for future deployments\):\\\n${CDEF})" -i "main" gitBranch \
  && echo -e "\n${CYELLOW}GitHub personal access tokens:${CDEF}" \
  && read -s accessTokenOrPassword && echo \
  && curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $accessTokenOrPassword" -H "X-GitHub-Api-Version: 2022-11-28" -o "$R.zip" "https://api.github.com/repos/SindlaXYZ/backend.itp.pro/zipball/$gitBranch" \
  && unzip "./$R.zip" -d . \
  && cd "./$(ls -d */ | head -1).docker" \
  && chmod +x Dockerfile.sh \
  && ./Dockerfile.sh "$accessTokenOrPassword"
```