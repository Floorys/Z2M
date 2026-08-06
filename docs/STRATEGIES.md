# Стратегии nfqws2

Стратегии zapret v1 (v1–v9, Flowseal и прочие наборы `--dpi-desync-*`)
**не работают** в nfqws2. Здесь другой синтаксис: фильтры + `--payload=` +
`--lua-desync=<функция>:параметр=значение`.

## Три слоя любой строки

1. **Фильтр профиля** — `--filter-tcp=`, `--filter-udp=`, `--filter-l7=`,
   `--hostlist=`, `--hostlist-exclude=`. Какой трафик вообще попадает в профиль.
2. **Фильтр пакета** — `--payload=` (`tls_client_hello`, `http_req`,
   `quic_initial`, `empty`, `known`) и `--out-range=`. К каким пакетам применять
   следующий desync.
3. **Действие** — `--lua-desync=`: `fake`, `multisplit`, `multidisorder`,
   `fakedsplit`, `tcpseg`, `pktmod`, `drop`.

Профили разделяются ключом `--new`.

## Шпаргалка перевода со старого zapret

| zapret v1 | nfqws2 |
| --- | --- |
| `--dpi-desync=fake` | `--lua-desync=fake:blob=fake_default_tls` |
| `--dpi-desync=multisplit` | `--lua-desync=multisplit:pos=...` |
| `--dpi-desync=fakedsplit` | `--lua-desync=fakedsplit:pos=...` |
| `--dpi-desync-fooling=md5sig` | `:tcp_md5` |
| `--dpi-desync-ttl=N` | `:ip_ttl=N` / `:ip6_ttl=N` |
| `--dpi-desync-autottl=-2,3-20` | `:ip_autottl=-2,3-20` |
| `--dpi-desync-split-pos=N` | `:pos=N` |
| `--dpi-desync-repeats=N` | `:repeats=N` |
| `--dpi-desync-fake-tls-mod=...` | `:tls_mod=...` |

Встроенные фейки: `fake_default_http`, `fake_default_tls`, `fake_default_quic`.

## Формат файла пресета

```
# name: короткое описание
# note: когда брать
# ports_tcp: 80,443
# ports_udp: 443
<строки опций nfqws2, профили разделены --new>
```

Комментарии читаются менеджером: `name` и `note` показываются в списке,
`ports_tcp` / `ports_udp` автоматически записываются в конфиг при применении.

## Что есть в комплекте

| Ид | Когда брать |
| --- | --- |
| `z1-default` | всегда первым — штатная строка апстрима |
| `z2-autottl` | фейк либо не долетает до DPI, либо ломает соединение |
| `z3-seqovl` | DPI собирает поток целиком, простой split не помогает |
| `z4-youtube` | YouTube тормозит или рвётся, остальное работает |
| `z5-http-fakedsplit` | блокируется обычный HTTP |
| `z6-quic` | TCP уже в порядке, видео по UDP тормозит |

## Как подбирать

1. `z2m strategy z1-default` — база.
2. `z2m test` — прогнать все пресеты по списку доменов.
3. Если ни один не взлетел — `z2m blockcheck` (долго, но честно).
4. Удачную строку из blockcheck сохранить: `z2m strategy save my-isp`.

Важно: тест с самого роутера и тест с клиента — разные вещи. Трафик самого
роутера идёт через цепочку output, клиентский — через forward. Финальную
проверку всегда делайте с компьютера за роутером.
