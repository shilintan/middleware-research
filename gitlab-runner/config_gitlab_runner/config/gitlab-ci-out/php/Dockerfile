FROM container.local.your-domain-name.com/base/php:v1
WORKDIR /app
COPY nginx.conf	  /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY . .
RUN rm -rf .git .gitlab-ci.yml ci.sh .travis.yml Dockerfile nginx.conf default.conf
#RUN rm -rf composer.json composer.lock
#RUN nginx -t
RUN set -ex \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 1024M/g" "$PHP_INI_DIR/php.ini" \
    && sed -i "s/post_max_size = 8M/post_max_size = 1024M/g" "$PHP_INI_DIR/php.ini" \
    && sed -i "s/max_execution_time = 30/max_execution_time = 600/g" "$PHP_INI_DIR/php.ini" \
    && sed -i "s/memory_limit = 128M/memory_limit = 1024M/g" "$PHP_INI_DIR/php.ini" \
    && sed -i "s/disable_functions =/disable_functions = passthru,exec,system,putenv,chroot,chgrp,chown,shell_exec,popen,proc_open,pcntl_exec,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,pcntl_waitpid,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,imap_open,apache_setenv/g" "$PHP_INI_DIR/php.ini" \
    && sed -i "s/pm.max_children = 5/pm.max_children = 5000/g" /usr/local/etc/php-fpm.d/www.conf \
    && sed -i "s/pm.start_servers = 2/pm.start_servers = 100/g" /usr/local/etc/php-fpm.d/www.conf \
    && sed -i "s/pm.min_spare_servers = 1/pm.min_spare_servers = 50/g" /usr/local/etc/php-fpm.d/www.conf \
    && sed -i "s/pm.max_spare_servers = 3/pm.max_spare_servers = 5000/g" /usr/local/etc/php-fpm.d/www.conf

CMD ["sh","-c","nginx && php-fpm"]