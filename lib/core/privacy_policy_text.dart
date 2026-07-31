/// Полный текст политики конфиденциальности — вынесен отдельно от
/// core/localization.dart, т.к. это длинный юридический текст, а не короткая
/// UI-строка вроде тех, что живут в T.dict. Версия — дата последней
/// содержательной правки; при её изменении экран согласия
/// (PrivacyConsentScreen) должен снова показаться даже тем, кто уже принял
/// предыдущую версию (сравнение версии — в main.dart).
const String kPrivacyPolicyVersion = '2026-07-31';

const String kPrivacyPolicyRu = '''
# Политика конфиденциальности Clarify

Последнее обновление: 31 июля 2026 г.

Используя Clarify («приложение», «сервис»), вы соглашаетесь с обработкой ваших персональных данных в соответствии с этой политикой.

## 1. Какие данные мы собираем

- **Данные для входа**: email-адрес (при входе по коду/паролю) или данные вашего аккаунта Яндекс (при входе через Яндекс ID) — имя, идентификатор аккаунта.
- **Данные профиля**: имя, аватар (если вы их указали).
- **Пользовательский контент**: задачи, заметки, проекты, сообщения в мессенджере приложения (личные и командные).
- **Данные команд**: код друга, состав команд/воркспейсов, к которым вы присоединились.
- **Технические данные**: язык интерфейса, настройки приложения, локальный офлайн-кэш задач на устройстве.

## 2. Для чего мы используем данные

- Аутентификация и работа с аккаунтом.
- Хранение и синхронизация ваших задач и сообщений между устройствами.
- Работа AI-ассистента: текст, который вы отправляете для разбора в задачи, передаётся стороннему провайдеру AI-моделей (см. п.3) для обработки.
- Push- и локальные уведомления о задачах (если вы их включили).
- Ответы на обращения в поддержку.

## 3. Кому мы передаём данные

Мы не продаём и не передаём ваши данные третьим лицам в рекламных целях. Для работы сервиса данные обрабатываются следующими подрядчиками:

- **Supabase** — хранение базы данных, аутентификация, файлы (аватары), realtime-синхронизация.
- **OpenRouter** — обработка текста задач AI-моделью при использовании AI-ассистента (только текст, который вы явно отправили ассистенту).
- **Яндекс** — при входе через Яндекс ID, обмен OAuth-кода на данные аккаунта.
- **Render** — хостинг вспомогательного backend-сервера приложения.

Каждый из этих подрядчиков обрабатывает данные в рамках своих собственных условий использования и политик конфиденциальности.

## 4. Хранение и защита данных

Данные передаются по защищённым каналам (HTTPS/TLS). Доступ к данным в базе ограничен политиками row-level security — вы видите и можете изменять только свои данные и данные команд, участником которых являетесь. Данные хранятся, пока ваш аккаунт активен, либо до тех пор, пока вы не запросите их удаление.

## 5. Ваши права

Вы можете в любой момент:

- запросить экспорт своих задач (раздел «Настройки» → «Экспорт задач в CSV»);
- изменить или удалить данные профиля;
- запросить полное удаление аккаунта и связанных с ним данных — напишите нам в поддержку (см. п.7);
- отозвать согласие на обработку данных, удалив аккаунт.

## 6. Локальное хранилище устройства

Приложение хранит часть данных локально на вашем устройстве (офлайн-кэш задач, настройки) для работы без подключения к интернету и быстрого запуска. Эти данные не передаются третьим лицам напрямую — только синхронизируются с вашей учётной записью через Supabase.

## 7. Возрастные ограничения

Сервис не предназначен для лиц младше 16 лет.

## 8. Изменения политики

При существенных изменениях этой политики мы попросим вас подтвердить согласие с новой версией при следующем входе в приложение.

## 9. Контакты

По вопросам обработки персональных данных, включая запросы на удаление аккаунта, пишите в поддержку: t.me/ClarifyPlan
''';

const String kPrivacyPolicyEn = '''
# Clarify Privacy Policy

Last updated: July 31, 2026

By using Clarify (the "app", "service"), you agree to the processing of your personal data as described in this policy.

## 1. Data we collect

- **Sign-in data**: email address (code/password sign-in) or your Yandex ID account data (name, account identifier) when signing in via Yandex.
- **Profile data**: name, avatar (if provided).
- **User content**: tasks, notes, projects, in-app messages (direct and team).
- **Team data**: friend code, teams/workspaces you belong to.
- **Technical data**: interface language, app settings, local offline task cache on your device.

## 2. How we use it

- Authentication and account management.
- Storing and syncing your tasks and messages across devices.
- AI assistant: text you send for parsing into tasks is forwarded to a third-party AI model provider (see section 3) for processing.
- Push and local task reminders (if enabled).
- Responding to support requests.

## 3. Who we share data with

We do not sell your data or share it with third parties for advertising. To operate the service, data is processed by:

- **Supabase** — database, authentication, file storage (avatars), realtime sync.
- **OpenRouter** — processes task text via an AI model when you use the AI assistant (only text you explicitly sent to it).
- **Yandex** — OAuth code exchange for account data when signing in via Yandex ID.
- **Render** — hosting for the app's auxiliary backend server.

Each processor handles data under its own terms and privacy policy.

## 4. Storage and security

Data is transmitted over secure channels (HTTPS/TLS). Database access is restricted by row-level security policies — you can only see and modify your own data and data of teams you belong to. Data is retained while your account is active, or until you request deletion.

## 5. Your rights

At any time you can:

- export your tasks (Settings → Export tasks to CSV);
- edit or delete your profile data;
- request full account deletion — contact support (see section 7);
- withdraw consent by deleting your account.

## 6. Local device storage

The app stores some data locally on your device (offline task cache, settings) to work without an internet connection and start up quickly. This data isn't shared with third parties directly — it's only synced to your account via Supabase.

## 7. Age restriction

The service isn't intended for people under 16.

## 8. Policy changes

For material changes to this policy, we'll ask you to re-confirm consent to the new version the next time you open the app.

## 9. Contact

For questions about personal data processing, including account deletion requests, contact support: t.me/ClarifyPlan
''';
