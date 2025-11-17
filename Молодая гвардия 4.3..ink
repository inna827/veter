INCLUDE Молодая гвардия 3.3..ink

Once upon a time...

 * There were two choices.
 * There were four lines of content.

- They lived happily ever after.
    -> END
    
    
import time
import random
import sys # Для sys.exit() и sys.stdout.write

# --- Глобальные переменные для состояния игры ---
player_name = ""
player_gender = ""
player_path = "neutral" # 'resistance', 'survival', 'forced_resistance', 'betrayal'
inventory = [] # Хранит объекты Item
player_stats = {
    'courage': 5,      # Смелость, влияет на бой и рискованные действия
    'stealth': 5,      # Скрытность, влияет на незаметность
    'ingenuity': 5,    # Изобретательность, влияет на обман, отвлечение
    'loyalty_resistance': 50, # От 0 до 100, влияет на доверие Молодой Гвардии и их отношение
    'loyalty_enemy': 0,      # От 0 до 100, влияет на доверие немцев и их отношение
    'health': 100,     # Здоровье
    'ammo_pistol': 0   # Количество патронов для пистолета
}
game_events = {
    'leaflet_spread_success': 0,
    'leaflet_spread_fail': 0,
    'has_pistol': False,        # Флаг наличия пистолета
    'has_molotov_components': False, # Компоненты для сборки Молотова (для реализма)
    'has_grenade': False,
    'tretyakevich_fate': 'unknown', # 'unknown', 'arrested', 'betrayed', 'saved', 'betrayed_by_circumstance'
    'underground_exposed_level': 0, # Уровень раскрытия подполья (0-5, 5 - полностью раскрыто)
    'rescued_ulyana': False,    # Флаг спасения Ульяны в последней миссии
    'acted_heroically_in_m4': False, # Флаг для героической концовки (если пожертвовал собой, но спас кого-то)
    'betrayal_degree': 0,        # 0 - нет, 1 - отрекшийся/изгой, 2 - приспособленец (спасшийся ценой души), 3 - слуга врага
    'met_lyubov': False,         # Встретил ли игрок Любовь Шевцову
    'met_sergey': False          # Встретил ли игрок Сергея Тюленина
}

# --- Классы для игровых объектов ---

class Item:
    def __init__(self, name, description, item_type="consumable", effect=None):
        self.name = name
        self.description = description
        self.item_type = item_type # 'weapon', 'consumable', 'key_item', 'resource', 'ammo'
        self.effect = effect if effect is not None else {} # Словарь, например {'health': 20} или {'stealth_bonus': 2}

    def __eq__(self, other):
        return isinstance(other, Item) and self.name == other.name

    def __hash__(self):
        return hash(self.name)

    def use(self, player):
        slow_print(f"Используете: {self.name}")
        if self.item_type == "consumable":
            for stat, value in self.effect.items():
                if stat == 'health':
                    player.player_stats['health'] = min(100, player.player_stats['health'] + value)
                    slow_print(f"Здоровье восстановлено на {value}. Текущее здоровье: {player.player_stats['health']}")
            # Удаляем используемый предмет
            if self in inventory:
                inventory.remove(self)
                return True
        elif self.item_type == "ammo":
            player.player_stats['ammo_pistol'] += self.effect.get('ammo_pistol', 0)
            slow_print(f"Вы подобрали {self.effect.get('ammo_pistol', 0)} патронов. Всего: {player.player_stats['ammo_pistol']}")
            if self in inventory:
                inventory.remove(self) # Патроны используются сразу при поднятии
                return True
        elif self.item_type == "weapon":
            # Просто установка флага, в этой текстовой версии "экипировка" не имеет сложной механики
            # Предполагаем, что как только предмет попадает в инвентарь, он "экипирован" для использования
            slow_print(f"Вы теперь можете использовать {self.name}.")
            return True
        else:
            slow_print("Этот предмет пока нельзя использовать так просто.")
        return False # Предмет не был использован или не требует удаления

class Character:
    def __init__(self, name, description, personality, initial_relationship=50):
        self.name = name
        self.description = description
        self.personality = personality # Краткое описание характера
        self.relationship = initial_relationship # От 0 до 100, отношение к игроку

    def talk(self, message):
        slow_print(f"[{self.name} ({self.personality})]: {message}")

# --- Предметы ---
items_data = {
    "Листовки": Item("Листовки", "Пропагандистские материалы для распространения.", "key_item"),
    "Аптечка": Item("Аптечка", "Небольшой запас медикаментов, способный залечить раны.", "consumable", {'health': 30}),
    "Пистолет (Walther P38)": Item("Пистолет (Walther P38)", "Надежный немецкий пистолет. Требует патронов.", "weapon"),
    "Патроны (5 шт.)": Item("Патроны (5 шт.)", "Несколько патронов для пистолета.", "ammo", {'ammo_pistol': 5}),
    "Патроны (10 шт.)": Item("Патроны (10 шт.)", "Больше патронов для пистолета.", "ammo", {'ammo_pistol': 10}),
    "Компоненты Молотова": Item("Компоненты Молотова", "Пустая бутылка, бензин, тряпка. Можно собрать Коктейль Молотова.", "key_item"),
    "Собранный Коктейль Молотова": Item("Собранный Коктейль Молотова", "Бутылка с зажигательной смесью. Готов к использованию.", "weapon"),
    "Граната (РГД-33)": Item("Граната (РГД-33)", "Советская ручная граната. Мощное, но шумное оружие.", "weapon"),
    "Подпольные средства": Item("Подпольные средства", "Местная валюта подполья или ценности. Можно обменять на припасы.", "resource", {'value': 10}),
    "Записка": Item("Записка", "Какая-то шифровка или важная информация. Возможно, ключ к тайне.", "key_item"),
    "Улучшенные листовки": Item("Улучшенные листовки", "Более убедительные и стилистически оформленные листовки.", "key_item", {'stealth_bonus': 1}), # Пример бонуса от предмета
    "Немецкая форма": Item("Немецкая форма", "Форма полицая или немецкого солдата. Позволяет маскироваться.", "key_item", {'stealth_bonus': 3}),
    "Наркотики": Item("Наркотики", "Запрещенные вещества. Могут быть использованы для отвлечения или компрометации.", "key_item")
}

# --- Персонажи ---
characters = {
    "Ульяна Громова": Character("Ульяна Громова", "Лидер, решительная, харизматичная. Ее взгляд проникает в душу, призывая к действию.", "лидер"),
    "Иван Земнухов": Character("Иван Земнухов", "Хитрый, находчивый, отвечающий за разведку. Всегда знает, где достать нужное, и как выпутаться из беды.", "разведчик"),
    "Сергей Тюленин": Character("Сергей Тюленин", "Смелый, порывистый, отвечающий за диверсии. Неудержим в бою, всегда готов к риску.", "диверсант"),
    "Любовь Шевцова": Character("Любовь Шевцова", "Артистичная, обаятельная, использующая свою внешность и актерский талант для сбора информации. Реплики игривые, но содержательные.", "агент"),
    "Виктор Третьякевич": Character("Виктор Третьякевич", "Изначально один из организаторов, но может сломиться под давлением. Его глаза полны тревоги и внутреннего конфликта.", "неопределившийся"),
    "Обер-лейтенант Мюллер": Character("Обер-лейтенант Мюллер", "Жестокий немецкий офицер СС, его взгляд холоден и пронизывающ, в голосе слышится неприкрытая угроза.", "враг"),
    "Игнат": Character("Игнат", "Местный коллаборационист, жадный и подлый. Его ухмылка вызывает отвращение.", "предатель"),
    "Патрульный": Character("Патрульный", "Обычный немецкий солдат на патруле, уставший, но опасный. Строго следует приказам.", "враг")
}

# --- Вспомогательные функции ---

def slow_print(text, delay=0.03):
    """Выводит текст посимвольно для атмосферности."""
    for char in text:
        sys.stdout.write(char)
        sys.stdout.flush()
        time.sleep(delay)
    print()

def get_choice(options):
    """Предлагает игроку выбор и возвращает номер выбранной опции."""
    for i, option in enumerate(options):
        slow_print(f"{i + 1}. {option}")
    while True:
        try:
            choice = int(input("\nВаш выбор: "))
            if 1 <= choice <= len(options):
                return choice
            else:
                slow_print("Неверный номер. Попробуйте еще раз.")
        except ValueError:
            slow_print("Пожалуйста, введите число.")

def display_inventory():
    """Отображает текущий инвентарь игрока и количество патронов."""
    if not inventory and player_stats['ammo_pistol'] == 0:
        slow_print("\n[Инвентарь пуст]")
        return
    slow_print("\n[ИНВЕНТАРЬ]:")
    if player_stats['ammo_pistol'] > 0:
        slow_print(f"- Патроны для пистолета: {player_stats['ammo_pistol']} шт.")

    # Чтобы избежать дублирования предметов, если их много, выводим уникальные
    # В реальной игре нужно хранить количество каждого предмета.
    unique_items_names = set()
    for item in inventory:
        unique_items_names.add(item.name)

    for i, item_name in enumerate(sorted(list(unique_items_names))):
        item_obj = next((item for item in inventory if item.name == item_name), None)
        if item_obj and item_obj.item_type != "ammo": # Патроны уже выведены
            slow_print(f"- {item_obj.name} - {item_obj.description}")
    slow_print("--------------------")

def display_status():
    """Показывает текущий статус игрока и ключевые флаги событий."""
    slow_print("\n--- ВАШ СТАТУС ---")
    slow_print(f"Имя: {player_name}")
    slow_print(f"Пол: {player_gender.capitalize()}")
    for stat, value in player_stats.items():
        if stat not in ['ammo_pistol']: # Патроны выводятся отдельно в инвентаре
            slow_print(f"{stat.capitalize()}: {value}")

    slow_print("\n[ПУТЬ И ПРОГРЕСС]:")
    slow_print(f"Выбранный путь: {player_path.replace('_', ' ').capitalize()}")
    slow_print(f"Доверие Сопротивлению: {player_stats['loyalty_resistance']}/100")
    slow_print(f"Доверие Оккупантам: {player_stats['loyalty_enemy']}/100")

    slow_print("\n[КЛЮЧЕВЫЕ ПРЕДМЕТЫ]:")
    if game_events['has_pistol']: slow_print("- Есть пистолет (Walther P38)")
    if game_events['has_molotov_components']: slow_print("- Есть компоненты для Коктейля Молотова")
    if check_item_in_inventory(items_data["Собранный Коктейль Молотова"]): slow_print("- Есть Собранный Коктейль Молотова")
    if game_events['has_grenade']: slow_print("- Есть граната (РГД-33)")

    slow_print(f"Уровень раскрытия подполья: {game_events['underground_exposed_level']}/5")
    slow_print("-------------------\n")

def game_over(reason):
    """Завершает игру с указанным сообщением."""
    slow_print("\n" + "="*50)
    slow_print("ИГРА ОКОНЧЕНА")
    slow_print(f"Причина: {reason}")
    slow_print("="*50)
    sys.exit()

def simulate_skill_check(skill_name, difficulty, bonus_item_name=None):
    """
    Проверяет навык игрока против сложности.
    Возвращает True при успехе, False при неудаче.
    Успех = (skill + случайное число 1-10) >= (difficulty + базовый порог 5)
    """
    player_skill = player_stats.get(skill_name, 0)

    if bonus_item_name:
        item_obj = items_data.get(bonus_item_name)
        if item_obj and check_item_in_inventory(item_obj) and item_obj.effect:
            player_skill += item_obj.effect.get(f'{skill_name}_bonus', 0)

    roll = random.randint(1, 10) + player_skill
    slow_print(f"Проверка {skill_name.capitalize()} (сложность {difficulty}). Ваш навык: {player_skill}. Бросок: {roll}")
    time.sleep(1)
    if roll >= difficulty + 5: # Базовый порог 5 для "средней" проверки
        slow_print("Проверка успешна!")
        return True
    else:
        slow_print("Проверка провалена.")
        return False

def simulate_combat_encounter(enemy_strength, weapon_used_name=None):
    """
    Симулирует боевое столкновение.
    Возвращает True при победе игрока, False при поражении.
    """
    slow_print(f"Боевое столкновение! Сила противника: {enemy_strength}")
    player_strength = player_stats['courage']

    # Применяем бонусы от оружия
    if weapon_used_name == items_data["Пистолет (Walther P38)"].name and game_events['has_pistol'] and player_stats['ammo_pistol'] > 0:
        player_strength += 3 # Бонус от пистолета
        player_stats['ammo_pistol'] = max(0, player_stats['ammo_pistol'] - 1)
        slow_print(f"Используете пистолет. Патроны -1. Осталось: {player_stats['ammo_pistol']}")
    elif weapon_used_name == items_data["Собранный Коктейль Молотова"].name and check_item_in_inventory(items_data["Собранный Коктейль Молотова"]):
        player_strength += 5 # Больший бонус за диверсию
        remove_item_from_inventory(items_data["Собранный Коктейль Молотова"])
        slow_print("Используете Коктейль Молотова.")
    elif weapon_used_name == items_data["Граната (РГД-33)"].name and game_events['has_grenade'] and check_item_in_inventory(items_data["Граната (РГД-33)"]):
        player_strength += 7 # Еще больший бонус
        remove_item_from_inventory(items_data["Граната (РГД-33)"])
        slow_print("Используете гранату.")

    player_roll = random.randint(1, 10) + player_strength
    enemy_roll = random.randint(1, 10) + enemy_strength

    slow_print(f"Ваш бросок: {player_roll}, бросок противника: {enemy_roll}")
    time.sleep(1)
    if player_roll >= enemy_roll:
        slow_print("Вы одержали победу в бою!")
        return True
    else:
        slow_print("Вы проиграли в бою!")
        return False

def add_item_to_inventory(item_object):
    """Добавляет предмет в инвентарь или обрабатывает его как патроны/флаги оружия."""
    if item_object.item_type == "ammo":
        item_object.use(None) # Патроны сразу добавляются к player_stats
    else:
        # Установка флагов для уникальных предметов/оружия
        if item_object.name == items_data["Пистолет (Walther P38)"].name:
            game_events['has_pistol'] = True
        elif item_object.name == items_data["Компоненты Молотова"].name:
            game_events['has_molotov_components'] = True
        elif item_object.name == items_data["Граната (РГД-33)"].name:
            game_events['has_grenade'] = True

        # Только если это не компоненты, которые уже преобразованы в "собранный" Молотов
        if not (item_object.name == items_data["Компоненты Молотова"].name and check_item_in_inventory(items_data["Собранный Коктейль Молотова"])):
            inventory.append(item_object)
            slow_print(f"Вы получили: {item_object.name}")

def remove_item_from_inventory(item_object):
    """Удаляет предмет из инвентаря и сбрасывает связанные флаги."""
    if item_object in inventory:
        inventory.remove(item_object)
        slow_print(f"Предмет {item_object.name} удален из инвентаря.")

        # Сброс флагов для уникальных предметов/оружия
        if item_object.name == items_data["Пистолет (Walther P38)"].name:
            game_events['has_pistol'] = False
        elif item_object.name == items_data["Компоненты Молотова"].name:
            game_events['has_molotov_components'] = False
        elif item_object.name == items_data["Граната (РГД-33)"].name:
            game_events['has_grenade'] = False
        elif item_object.name == items_data["Собранный Коктейль Молотова"].name:
             # Если использован собранный Молотов, то компоненты тоже "подразумеваются" использованными
            game_events['has_molotov_components'] = False 
        return True
    return False

def check_item_in_inventory(item_object):
    """Проверяет наличие предмета в инвентаре."""
    return item_object in inventory

def loot_box():
    """Игрок находит случайные предметы в ящике."""
    slow_print("\nВы нашли старый, присыпанный мусором ящик. Что внутри?")
    possible_loot = [
        items_data["Аптечка"],
        items_data["Патроны (5 шт.)"],
        items_data["Компоненты Молотова"],
        items_data["Граната (РГД-33)"],
        items_data["Подпольные средства"],
        items_data["Записка"],
        items_data["Пистолет (Walther P38)"],
        items_data["Наркотики"]
    ]

    loot_count = random.randint(1, 3) # От 1 до 3 предметов
    found_items = random.sample(possible_loot, loot_count) # Выбираем уникальные предметы

    for item in found_items:
        # Уникальные предметы (оружие, компоненты) добавляем только если их нет
        if (item.item_type == "weapon" and (
            (item.name == items_data["Пистолет (Walther P38)"].name and game_events['has_pistol']) or
            (item.name == items_data["Граната (РГД-33)"].name and game_events['has_grenade']) or
            (item.name == items_data["Собранный Коктейль Молотова"].name and check_item_in_inventory(items_data["Собранный Коктейль Молотова"]))
        )):
            slow_print(f"У вас уже есть {item.name}. (не добавляется)")
        elif item.name == items_data["Компоненты Молотова"].name and game_events['has_molotov_components']:
            slow_print(f"У вас уже есть {item.name}. (не добавляется)")
        elif item.item_type == "key_item" and check_item_in_inventory(item):
            slow_print(f"У вас уже есть {item.name}. (не добавляется)")
        else:
            add_item_to_inventory(item)
    time.sleep(1)

def historical_note(title, text):
    """Выводит историческую справку для погружения."""
    slow_print(f"\n--- Историческая справка: {title} ---")
    slow_print(text)
    slow_print("-----------------------------------")
    time.sleep(4) # Дать игроку время прочитать

# --- Сцены/Узлы сюжета ---

def prologue():
    global player_name, player_gender, player_path
    slow_print("Добро пожаловать в 'Эхо Подвига: Молодая Гвардия'!")
    slow_print("--------------------------------------------------")
    slow_print("На дворе 1942 год. Тихий шахтерский городок Краснодон, Ворошиловградской области.")
    slow_print("Мирная жизнь, полная юношеских мечтаний и планов, рухнула под натиском войны.")
    time.sleep(2)

    player_name = input("Как вас зовут? ")
    gender_choice = get_choice(["Я парень", "Я девушка"])
    player_gender = "парень" if gender_choice == 1 else "девушка"

    slow_print(f"\n{player_name}, {player_gender}, вы жили обычной жизнью, пока война не пришла на порог.")
    slow_print("Немецкие солдаты заняли город. Улицы изменились, на них появились патрули и комендантский час.")
    slow_print("Страх и отчаяние поселились в сердцах людей, но где-то тлела искра надежды.")
    time.sleep(3)
    slow_print("Вы видите, как немецкий патруль жестоко избивает старика на площади за то, что тот не снял шапку перед офицером.")
    slow_print("Вам становится не по себе. В груди зарождается что-то, чего раньше не было – гнев, отвращение, желание сопротивляться...")
    time.sleep(3)

    slow_print("\nВскоре к вам обращается Ульяна Громова, которую вы знали по школе. Она предлагает вступить в подпольную организацию.")
    slow_print("Это опасно. Это смертельно. Но это шанс что-то изменить, бороться за свою Родину.")

    choice = get_choice([
        "1. Присоединиться к подполью. Рискнуть всем ради борьбы.",
        "2. Искать свой путь. Попытаться выжить, избегая конфликтов, но оставаясь на передовой событий."
    ])

    if choice == 1:
        player_path = "resistance"
        player_stats['loyalty_resistance'] = 70 # Стартовая лояльность сопротивлению выше
        characters["Ульяна Громова"].relationship = 70
        slow_print("\nВы выбрали путь сопротивления. Ваша жизнь теперь принадлежит борьбе за свободу. Вы не можете оставаться в стороне.")
        time.sleep(2)
        mission1_resistance()
    else:
        player_path = "survival"
        player_stats['loyalty_resistance'] = 30 # Стартовая лояльность сопротивлению ниже
        characters["Ульяна Громова"].relationship = 30 # Отношение к Ульяне снижается, так как вы отказались
        slow_print("\nВы решили держаться в стороне, стараясь выжить любой ценой. Но война не оставляет человека в покое.")
        time.sleep(2)
        early_survival_path()

# --- Ветка Сопротивления ---

def mission1_resistance():
    slow_print("\n--- Миссия 1: «Первые шаги» ---")
    slow_print("Ваш первый контакт с подпольем. Группа собирается в тайном убежище, замаскированном под заброшенный подвал.")
    characters["Ульяна Громова"].talk(f"Привет, {player_name}. Рада, что ты с нами. Начнем с малого, но очень важного. Нужно распространить наши листовки по всему городу.")
    slow_print("Вам вручают пачку 'Листовок', написанных от руки. На них призывы к саботажу и борьбе, сводки с фронтов.")
    add_item_to_inventory(items_data["Листовки"])
    display_status()

    slow_print("\nНужно расклеить листовки незаметно для немецких патрулей. Город кишит ими.")
    slow_print("Вы стоите на развилке: центральная улица с большей проходимостью и риском, или тихие дворы и переулки, где шанс быть замеченным ниже.")

    choice = get_choice([
        "1. Через центральную улицу (высокий риск быть замеченным, но большой охват).",
        "2. Через дворы и переулки (меньше риск, но дольше и охват меньше)."
    ])

    stealth_difficulty = 7 if choice == 1 else 5
    if simulate_skill_check("stealth", stealth_difficulty):
        slow_print("Вы успешно расклеили листовки, действуя как тень. Немцы ничего не заметили. Жители читают их с надеждой.")
        game_events['leaflet_spread_success'] += 1
        player_stats['stealth'] += 1
        player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 10)
        characters["Ульяна Громова"].relationship = min(100, characters["Ульяна Громова"].relationship + 10)
        characters["Ульяна Громова"].talk(f"Отличная работа, {player_name}! Так держать. Каждый листочек - это пуля в сердце врага.")
        remove_item_from_inventory(items_data["Листовки"])
        time.sleep(2)
        mission2_resistance()
    else:
        slow_print("Вас почти заметили! Пришлось бросить листовки и бежать, чтобы не быть схваченным. Вы видели, как патруль схватил случайного прохожего, который пытался подобрать одну из листовок.")
        game_events['leaflet_spread_fail'] += 1
        player_stats['health'] -= 10
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 10)
        characters["Ульяна Громова"].relationship = max(0, characters["Ульяна Громова"].relationship - 10)
        slow_print(f"Текущее здоровье: {player_stats['health']}")
        characters["Ульяна Громова"].talk(f"Жаль, но это тоже опыт, {player_name}. Будь осторожнее. На войне без потерь не бывает.")
        remove_item_from_inventory(items_data["Листовки"])
        time.sleep(2)
        mission2_resistance() # Продолжаем, но с последствиями

def mission2_resistance():
    slow_print("\n--- Миссия 2: «Пламя Надежды» ---")
    slow_print("Молодая гвардия планирует более серьезную операцию. Нужны оружие и припасы для диверсий.")
    characters["Сергей Тюленин"].talk("Мы знаем о старом схроне на окраине города, где партизаны могли оставить что-то. Там могут быть кое-какие вещи. Но место это опасно, немцы иногда патрулируют.")
    game_events['met_sergey'] = True # Игрок встретил Сергея
    display_status()

    options = [
        "1. Отправиться на поиски схрона, действуя скрытно.",
        "2. Предложить Любови Шевцовой использовать ее обаяние для сбора информации или отвлечения.",
        "3. Сказать, что слишком опасно (потеряете доверие)."
    ]
    choice = get_choice(options)

    if choice == 1:
        slow_print("Вы отправляетесь к схрону. Путь лежит через пустыри и разрушенные дома, мимо заброшенных шахт.")
        time.sleep(2)
        if random.random() < 0.6: # Шанс найти ящик
            loot_box()

        # Шанс столкнуться с патрулем
        if random.random() < 0.4:
            slow_print("\nВы столкнулись с небольшим немецким патрулем! Их трое.")
            combat_choice = get_choice([
                "1. Попытаться скрыться (проверка скрытности).",
                "2. Вступить в бой (если есть оружие).",
                "3. Отвлечь внимание, создав шум (проверка изобретательности)."
            ])

            if combat_choice == 1:
                if simulate_skill_check("stealth", 8):
                    slow_print("Вы успешно скрылись от патруля, затаившись в тенях. Они прошли мимо.")
                    player_stats['stealth'] += 1
                else:
                    slow_print("Патруль вас заметил! Пришлось броситься наутек, вы получили легкое ранение, когда один из них открыл огонь.")
                    player_stats['health'] -= 20
                    slow_print(f"Текущее здоровье: {player_stats['health']}")
            elif combat_choice == 2 and (game_events['has_pistol'] or game_events['has_molotov_components'] or game_events['has_grenade']):
                weapon_to_use = None
                if game_events['has_pistol'] and player_stats['ammo_pistol'] > 0: weapon_to_use = items_data["Пистолет (Walther P38)"].name
                elif game_events['has_molotov_components']: 
                    add_item_to_inventory(items_data["Собранный Коктейль Молотова"]) # Собираем для использования
                    weapon_to_use = items_data["Собранный Коктейль Молотова"].name
                elif game_events['has_grenade']: weapon_to_use = items_data["Граната (РГД-33)"].name

                if weapon_to_use:
                    if simulate_combat_encounter(6, weapon_to_use):
                        slow_print("Вы справились с патрулем! Но стрельба привлекла внимание. Возможно, это приведет к более тщательным поискам.")
                        game_events['underground_exposed_level'] = min(5, game_events['underground_exposed_level'] + 1)
                        player_stats['courage'] += 2
                    else:
                        slow_print("Патруль оказался слишком сильным. Вам удалось сбежать, но вы сильно ранены.")
                        player_stats['health'] -= 40
                        slow_print(f"Текущее здоровье: {player_stats['health']}")
                        if player_stats['health'] <= 0: game_over("Вы погибли в схватке, пытаясь добыть припасы.")
                else: # Если оружия нет, но пытались воевать
                    slow_print("У вас нет подходящего оружия или патронов для боя. Пришлось бежать, получив ранение.")
                    player_stats['health'] -= 20
                    slow_print(f"Текущее здоровье: {player_stats['health']}")
                    if player_stats['health'] <= 0: game_over("Вы погибли, не имея средств для борьбы.")

            elif combat_choice == 3:
                if simulate_skill_check("ingenuity", 7):
                    slow_print("Вы успешно отвлекли патруль, бросив камень в сторону разрушенного здания. Это дало вам время скрыться.")
                    player_stats['ingenuity'] += 1
                else:
                    slow_print("Ваша попытка отвлечь внимание не удалась, патруль вас заметил и открыл огонь.")
                    player_stats['health'] -= 30
                    slow_print(f"Текущее здоровье: {player_stats['health']}")
                    if player_stats['health'] <= 0: game_over("Вы погибли, пытаясь отвлечь внимание.")

        slow_print("\nВы возвращаетесь к Молодой Гвардии с добычей (или без нее).")
        player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 10)
        mission3_resistance()
    elif choice == 2:
        slow_print("Вы предлагаете Любови Шевцовой использовать ее навыки. Она с улыбкой соглашается.")
        characters["Любовь Шевцова"].talk("Я знаю, как отвлечь этих фрицев. Главное - держать их на крючке. А вы пока выясните, что нужно.")
        game_events['met_lyubov'] = True # Игрок встретил Любовь
        slow_print("Любовь отправляется в город, используя свою внешность и обаяние, чтобы собрать информацию о передвижении патрулей и складах.")
        if random.random() < 0.8: # Высокий шанс успеха Любови
            slow_print("Ей удается узнать о небольшом складе, где хранится топливо и старые винтовки.")
            add_item_to_inventory(items_data["Граната (РГД-33)"]) # Пример добычи через Любовь
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 8)
            characters["Любовь Шевцова"].relationship = min(100, characters["Любовь Шевцова"].relationship + 10)
            slow_print("Вы получили 'Граната (РГД-33)' от Любови.")
        else:
            slow_print("Любови не удалось добыть что-то существенное, но она не вызвала подозрений.")
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 3)
            characters["Любовь Шевцова"].relationship = min(100, characters["Любовь Шевцова"].relationship + 3)
        time.sleep(2)
        mission3_resistance()
    else:
        slow_print("Вы отказываетесь, ссылаясь на опасность. Сергей Тюленин недоволен, доверие к вам падает.")
        characters["Сергей Тюленин"].relationship = max(0, characters["Сергей Тюленин"].relationship - 10)
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 10)
        slow_print("Молодой гвардии пришлось искать другой способ, без вашей помощи.")
        time.sleep(2)
        mission3_resistance()

def mission3_resistance():
    slow_print("\n--- Миссия 3: «Сквозь огонь» ---")
    slow_print("Молодая Гвардия готова к своей первой крупной диверсии. Цель – немецкий склад с боеприпасами или топливом.")
    characters["Ульяна Громова"].talk(f"Нам нужна твоя помощь, {player_name}. Нужно добраться до склада и вывести его из строя. Это будет серьезный удар по врагу.")
    display_status()

    has_molotov_components_for_assembly = check_item_in_inventory(items_data["Компоненты Молотова"])
    has_molotov_ready = check_item_in_inventory(items_data["Собранный Коктейль Молотова"])
    has_grenade = game_events['has_grenade'] and check_item_in_inventory(items_data["Граната (РГД-33)"])

    options = []
    if has_molotov_components_for_assembly and not has_molotov_ready:
        options.append("1. Собрать Коктейль Молотова и использовать для поджога.")
    if has_molotov_ready: 
        options.append(f"{len(options)+1}. Использовать уже собранный Коктейль Молотова для поджога.")
    if has_grenade: 
        options.append(f"{len(options)+1}. Использовать Гранату (РГД-33) для уничтожения склада.")
    options.append(f"{len(options)+1}. Попытаться проникнуть и саботировать изнутри (требует высокой скрытности).")
    options.append(f"{len(options)+1}. Отказаться (очень сильно подорвет доверие и может изменить ваш путь).")

    choice = get_choice(options)

    action_chosen = ""
    # Определяем выбранное действие
    if "Собрать Коктейль Молотова" in options[choice-1]:
        slow_print("Вы быстро собираете Коктейль Молотова из компонентов.")
        remove_item_from_inventory(items_data["Компоненты Молотова"])
        add_item_to_inventory(items_data["Собранный Коктейль Молотова"])
        action_chosen = items_data["Собранный Коктейль Молотова"].name
    elif "Использовать уже собранный Коктейль Молотова" in options[choice-1]:
        action_chosen = items_data["Sобранный Коктейль Молотова"].name
    elif "Использовать Гранату (РГД-33)" in options[choice-1]:
        action_chosen = items_data["Граната (РГД-33)"].name
    elif "Попытаться проникнуть и саботировать изнутри" in options[choice-1]:
        action_chosen = "Sabotage"
    elif "Отказаться" in options[choice-1]:
        action_chosen = "Refuse"

    if action_chosen == "Refuse":
        slow_print("Вы отказываетесь участвовать в такой опасной диверсии. Молодая Гвардия смотрит на вас с разочарованием.")
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 20)
        characters["Ульяна Громова"].relationship = max(0, characters["Ульяна Громова"].relationship - 20)
        if player_stats['loyalty_resistance'] < 30: # Если лояльность упала очень сильно
            slow_print("Из-за вашей ненадежности вас отстраняют от активных действий. Вы чувствуете, что вас больше не считают частью их команды.")
            game_events['tretyakevich_fate'] = 'betrayed_by_circumstance' # Это может привести к тому, что вы будете "втянуты" в предательство
            player_path = "survival" # Сдвиг пути
        mission4_resistance()
        return

    slow_print("Вы пробираетесь к немецкому складу. Усиленные патрули, собаки, прожектора. Воздух пропитан напряжением.")

    if action_chosen == items_data["Собранный Коктейль Молотова"].name or action_chosen == items_data["Граната (РГД-33)"].name:
        if simulate_combat_encounter(8, action_chosen): # Высокая сложность боя
            slow_print("Вы успешно осуществили диверсию! Мощный взрыв и пожар охватили склад. Немцы в панике. Вы успели скрыться.")
            player_stats['courage'] += 5
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 15)
            game_events['underground_exposed_level'] = min(5, game_events['underground_exposed_level'] + 3)
        else:
            slow_print("Вам удалось осуществить диверсию, но вы были замечены! Пришлось бежать под шквальным огнем. К счастью, вы целы, но враг теперь знает, что здесь орудуют подпольщики.")
            player_stats['health'] -= 30
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 5)
            game_events['underground_exposed_level'] = min(5, game_events['underground_exposed_level'] + 4)
            slow_print(f"Текущее здоровье: {player_stats['health']}")
            if player_stats['health'] <= 0: game_over("Вы погибли, отступая после диверсии.")
    elif action_chosen == "Sabotage":
        if simulate_skill_check("stealth", 9): # Очень высокая сложность скрытности
            slow_print("Вы успешно проникли внутрь склада и вывели из строя ключевое оборудование, не подняв тревоги! Немцы ничего не заподозрили сразу.")
            player_stats['stealth'] += 5
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 15)
        else:
            slow_print("Вас обнаружили внутри склада! Завязался бой, вам удалось саботировать часть оборудования, но пришлось бежать. Вы получили тяжелые ранения.")
            player_stats['health'] -= 50
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 5)
            game_events['underground_exposed_level'] = min(5, game_events['underground_exposed_level'] + 4)
            slow_print(f"Текущее здоровье: {player_stats['health']}")
            if player_stats['health'] <= 0: game_over("Вы погибли, саботируя склад врага.")

    slow_print("После диверсии напряжение в городе нарастает. Чувствуется приближение беды, немцы усилят репрессии.")
    mission4_resistance()

def mission4_resistance():
    slow_print("\n--- Миссия 4: «Последний бой» ---")
    slow_print("Критические дни для Молодой Гвардии. В городе витают слухи о предательстве и облавах. Немцы начинают массовые аресты.")
    characters["Иван Земнухов"].talk("Нас раскрыли, {player_name}! Облава! Немцы уже здесь, они окружили дом, где скрывается Ульяна! Нужно что-то делать!")
    display_status()

    if game_events['underground_exposed_level'] >= 4:
        slow_print("Из-за высокого уровня раскрытия немцы были начеку. Разгром подполья кажется неизбежным.")

    # Роль Виктора Третьякевича в этой миссии
    if game_events['tretyakevich_fate'] == 'betrayed_by_circumstance' or \
       (characters["Виктор Третьякевич"].relationship < 30 and player_stats['loyalty_resistance'] < 50):
        slow_print("Вы видите Виктора Третьякевича. Его лицо искажено страхом и отчаянием. Он указывает немцам на ваше укрытие!")
        characters["Виктор Третьякевич"].talk("Мне очень жаль, ребята... Но выбора не было.")
        slow_print("Вы окружены! Бой неравный, шансы малы. Предательство Виктора Третьякевича стало фатальным.")
        game_events['tretyakevich_fate'] = 'betrayed' # Фиксируем предательство
        time.sleep(2)
        if random.random() < 0.1 and player_stats['courage'] > 70: # Очень малый шанс героически отбиться
            slow_print("Вы сражаетесь отчаянно, давая другим время уйти, но сами получаете смертельное ранение. Ваша жертва не напрасна.")
            game_events['acted_heroically_in_m4'] = True
            heroic_ending()
        else:
            slow_print("Вас схватили. Сопротивление бесполезно. Ваши последние мысли - о предательстве и борьбе.")
            game_over("Арест и смерть от рук врага. Ваша жертва оказалась тщетной из-за предательства.")

    options = [
        "1. Скрытно пробраться к дому Ульяны, пытаясь ее спасти (высокий риск).",
        "2. Попытаться отвлечь немцев, создав шум в другом месте (меньший риск для себя, но возможно, не спасет Ульяну).",
        "3. Спрятаться и переждать облаву (попытка выжить любой ценой, но с чувством вины)."
    ]

    if game_events['has_pistol'] and player_stats['ammo_pistol'] > 0:
        options.insert(2, "4. Ворваться в бой, пытаясь спасти Ульяну силой (очень высокий риск, но героически).") # Вставляем как третий вариант
    elif game_events['has_pistol'] and player_stats['ammo_pistol'] == 0:
        options.insert(2, "4. Ворваться в бой (но нет патронов! Это чистое отчаяние).")

    choice_index = get_choice(options)
    chosen_option_text = options[choice_index-1] # Получаем текст выбранной опции

    if "Скрытно пробраться к дому Ульяны" in chosen_option_text:
        slow_print("Вы осторожно пробираетесь по темным улицам, избегая патрулей. Каждый шорох заставляет сердце биться быстрее.")
        if simulate_skill_check("stealth", 9): # Очень высокая сложность
            slow_print("Вы успешно пробрались к черному входу дома Ульяны. Она ждет вас! Вместе вы выбираетесь из города.")
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 20)
            game_events['rescued_ulyana'] = True
            heroic_ending()
        else:
            slow_print("Вас заметили! Завязалась перестрелка. Вам удалось отбиться, но Ульяну схватили на ваших глазах. Вы не смогли помочь и еле ушли.")
            player_stats['health'] -= 50
            if player_stats['health'] <= 0: game_over("Вы погибли, пытаясь спасти Ульяну.")
            survivor_ending() # Вы выжили, но Ульяна арестована
    elif "Ворваться в бой" in chosen_option_text:
        if game_events['has_pistol'] and player_stats['ammo_pistol'] > 0:
            slow_print("Вы решаетесь на отчаянный шаг! С оружием в руках вы бросаетесь на немцев, чтобы спасти Ульяну.")
            if simulate_combat_encounter(10, items_data["Пистолет (Walther P38)"].name): # Крайне высокая сложность
                slow_print("Вы героически сражаетесь, отвлекая огонь на себя. Ульяна успевает скрыться! Ваша жертва не напрасна.")
                game_events['acted_heroically_in_m4'] = True
                player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 20)
                player_stats['health'] -= 70 # Выжили, но с тяжелейшими ранениями
                if player_stats['health'] <= 0: game_over("Вы погибли, спасая Ульяну, но ее жизнь была спасена вашей жертвой.")
                heroic_ending()
            else:
                slow_print("Вы героически сражаетесь, но силы неравны. Вас хватают, Ульяна арестована. Ваши усилия оказались напрасными.")
                game_events['acted_heroically_in_m4'] = False # Не смогли спасти ее
                game_over("Вы погибли в неравном бою, пытаясь спасти Ульяну.")
        else: # Нет патронов или оружия
            slow_print("Вы ворвались в бой, но без оружия или патронов вы бессильны. Вас легко хватают, а Ульяну арестовывают.")
            game_over("Вас схватили в отчаянной, но безрассудной попытке спасти Ульяну.")
    elif "Попытаться отвлечь немцев" in chosen_option_text:
        slow_print("Вы решаете отвлечь немцев, создав шум в другом районе города. Это оттягивает их силы от дома Ульяны.")
        if simulate_skill_check("ingenuity", 8):
            slow_print("Ваше отвлечение сработало! Основные силы немцев оттянулись. Возможно, Ульяна и другие смогли уйти.")
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 10)
            survivor_ending() # Ульяна, возможно, спасена, но вы не были рядом
        else:
            slow_print("Ваша попытка отвлечения не удалась. Немцы быстро поняли обман и продолжили облаву. Вы ничего не смогли сделать.")
            survivor_ending() # Ульяна арестована, вы выжили, но с чувством вины
    elif "Спрятаться и переждать облаву" in chosen_option_text:
        slow_print("Вы находите укромное место и замираете. Облава длится несколько дней. Вы слышите крики, выстрелы, шум.")
        slow_print("Когда все стихает, вы узнаете о разгроме Молодой Гвардии. Многие погибли или арестованы, в том числе Ульяна.")
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 15)
        if random.random() < 0.2 and player_stats['loyalty_resistance'] < 30: # Шанс быть обнаруженным и арестованным, если лояльность низкая
            game_over("Вы пытались спрятаться, но вас обнаружили и арестовали. Ваша трусость привела к гибели.")
        survivor_ending() # Вы выжили, но с клеймом бездействия


# --- Ветка Выживания (Тропа Предательства) ---
def early_survival_path():
    slow_print("\n--- Ранний этап: «Искать свой путь» ---")
    slow_print("Вы стараетесь не привлекать к себе внимания. Улицы полны немецких патрулей, каждый день - борьба за выживание.")
    slow_print("Вы ищете еду, пытаетесь сохранить остатки нормальной жизни.")
    time.sleep(2)

    slow_print("Однажды, проходя мимо заброшенного дома на окраине, вы замечаете приоткрытую дверь и свежие следы на грязи.")

    choice = get_choice([
        "1. Зайти внутрь и осмотреться (возможно, там что-то ценное).",
        "2. Пройти мимо, не рискуя, чтобы не попасть в неприятности."
    ])

    if choice == 1:
        slow_print("Внутри вы находите небольшой тайник с 'Подпольными средствами' и аптечкой.")
        add_item_to_inventory(items_data["Подпольные средства"])
        add_item_to_inventory(items_data["Аптечка"])
        slow_print("Вы пополнили свои запасы. Возможно, это был чей-то схрон.")
    else:
        slow_print("Вы решаете не рисковать. Лучше не попадаться на глаза, особенно в таких местах.")

    slow_print("\nНа следующий день, возвращаясь с поиска еды, вы сталкиваетесь с немецким патрулем на улице. Они требуют документы.")
    characters["Патрульный"].talk("Halt! Papiere!") # Стой! Документы!

    options = [
        "1. Покорно отдать документы, пытаясь быть максимально вежливым и незаметным.",
        "2. Попытаться убежать, используя знание переулков (рискованно).",
    ]
    if game_events['has_pistol'] and player_stats['ammo_pistol'] > 0:
        options.append("3. Выхватить пистолет и попытаться обезвредить патруль (очень опасно!).")
    elif game_events['has_pistol'] and player_stats['ammo_pistol'] == 0:
        options.append("3. Выхватить пистолет (но патронов нет! Отчаянный жест).")

    choice_index = get_choice(options)
    chosen_option_text = options[choice_index-1]

    if "Покорно отдать документы" in chosen_option_text:
        if random.random() > 0.3: # 70% шанс, что не вызовете подозрений
            slow_print("Солдат хмурится, внимательно осматривает вас, но отдает документы. Вы вздыхаете с облегчением.")
            player_stats['loyalty_enemy'] = min(100, player_stats['loyalty_enemy'] + 5) # Небольшой бонус за подчинение
        else:
            slow_print("Солдат недоволен. Он начинает задавать вопросы, глядя на вас с подозрением. Вас доставляют в комендатуру.")
            player_stats['health'] -= 10
            player_stats['loyalty_enemy'] = max(0, player_stats['loyalty_enemy'] - 5) # На допросе могут быть проблемы
            characters["Обер-лейтенант Мюллер"].talk("Кажется, у нас тут кто-то не совсем лояльный.")
            survival_captured_or_turned()
            return
    elif "Попытаться убежать" in chosen_option_text:
        if simulate_skill_check("stealth", 7):
            slow_print("Вы резко рванули в ближайший переулок, используя свое знание города. Патруль потерял вас из виду.")
            player_stats['stealth'] += 1
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 5) # Враги недовольны, что хорошо для сопротивления
            player_stats['loyalty_enemy'] = max(0, player_stats['loyalty_enemy'] - 5)
        else:
            slow_print("Вы попытались убежать, но немцы оказались быстрее и выносливее. Вас схватили. Жестоко избивают и доставляют в комендатуру.")
            player_stats['health'] -= 30
            if player_stats['health'] <= 0: game_over("Вы погибли при задержании.")
            survival_captured_or_turned()
            return
    elif "Выхватить пистолет" in chosen_option_text:
        if game_events['has_pistol'] and player_stats['ammo_pistol'] > 0:
            if simulate_combat_encounter(7, items_data["Пистолет (Walther P38)"].name):
                slow_print("Вы выхватываете пистолет и открываете огонь! Вам удается ранить одного солдата, остальные в панике. Вы убегаете.")
                player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 10) # Подпольщики, возможно, услышат
                player_stats['loyalty_enemy'] = max(0, player_stats['loyalty_enemy'] - 10)
                player_stats['stealth'] = max(0, player_stats['stealth'] - 2) # Теперь вы разыскиваетесь
                slow_print("Но теперь вы в списке разыскиваемых. Навык скрытности -2.")
                slow_print("Слухи о вашем дерзком поступке достигают Молодой Гвардии. Ульяна Громова ищет вас.")
                player_path = "forced_resistance" # Принудительно на путь сопротивления
                mission2_resistance() # Возвращаем на путь сопротивления
                return
            else:
                slow_print("Вы выхватили пистолет и открыли огонь, но немцы оказались быстрее! Вас обезвреживают и хватают.")
                player_stats['health'] -= 40
                if player_stats['health'] <= 0: game_over("Вы погибли в схватке с патрулем.")
                survival_captured_or_turned()
                return
        else: # Нет патронов или оружия
            slow_print("Вы выхватили пистолет, но патронов нет! Патруль легко вас обезвреживает и хватает.")
            player_stats['health'] -= 20
            survival_captured_or_turned()
            return

    slow_print("\nПосле инцидента с патрулем, к вам подходит Игнат, местный коллаборационист. Он предлагает 'выгодное сотрудничество'.")
    survival_moral_dilemma()

def survival_moral_dilemma():
    slow_print("\n--- Моральные дилеммы ---")
    characters["Игнат"].talk("Слышал, ты в неприятности попал? Могу помочь. У немцев всегда есть работа для 'своих'.")
    slow_print("Игнат, мерзко ухмыляясь, предлагает вам работу: сообщать о подозрительных лицах и их действиях. Обещает еду, защиту и небольшие деньги.")
    display_status()

    options = [
        "1. Категорически отказаться, даже если это опасно. Сохранить честь.",
        "2. Согласиться, но постараться ничего ценного не сообщать, имитировать сотрудничество.",
        "3. Согласиться и полностью сотрудничать для собственной выгоды и безопасности."
    ]
    choice = get_choice(options)

    if choice == 1:
        slow_print("Вы отказываетесь. Игнат злобно смотрит на вас, но уходит. Теперь вы у него 'на карандаше'.")
        player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 10)
        player_stats['loyalty_enemy'] = max(0, player_stats['loyalty_enemy'] - 10)
        slow_print("Ваше положение ухудшилось, но совесть чиста. Возможно, вас заметят молодогвардейцы.")
        game_events['betrayal_degree'] = 1 # Отрекшийся / Изгой
        survival_rebellion_or_consequences()
    elif choice == 2:
        slow_print("Вы соглашаетесь, но решаете играть по своим правилам. Вы будете передавать общую, бесполезную информацию.")
        player_stats['loyalty_enemy'] = min(100, player_stats['loyalty_enemy'] + 10)
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 10)
        slow_print("Вы начали 'сотрудничать'. Это скользкий путь, требующий хитрости и осторожности.")
        game_events['betrayal_degree'] = 2 # Приспособленец (Спасшийся ценой души)
        survival_collaboration_mild()
    elif choice == 3:
        slow_print("Вы соглашаетесь и обещаете полную лояльность. Деньги и еда вам нужны, а совесть... она подождет. Или нет?")
        player_stats['loyalty_enemy'] = min(100, player_stats['loyalty_enemy'] + 20)
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 20)
        slow_print("Вы ступили на путь предательства. Отныне ваша судьба связана с оккупантами.")
        game_events['betrayal_degree'] = 3 # Слуга врага
        survival_collaboration_full()

def survival_rebellion_or_consequences():
    slow_print("\n--- Путь сопротивления или последствия ---")
    display_status()
    if player_stats['loyalty_resistance'] >= 70:
        slow_print("Ваш отказ от сотрудничества и ваша принципиальность не остались незамеченными. Вас находит Сергей Тюленин и предлагает присоединиться к Молодой Гвардии.")
        slow_print("Это ваш шанс искупить прежние страхи и встать на путь борьбы, по-настоящему стать частью сопротивления.")
        game_events['met_sergey'] = True
        options = [
            "1. Присоединиться к Сергею и Молодой Гвардии.",
            "2. Отказаться, боясь за свою жизнь (снова)."
        ]
        choice = get_choice(options)
        if choice == 1:
            player_path = "resistance"
            slow_print("Вы выбрали сторону света! Сергей радостно принимает вас. Вы начинаете новую жизнь в борьбе, полное опасности, но и смысла.")
            mission3_resistance() # Перепрыгиваем к более поздней миссии сопротивления
        else:
            slow_print("Вы отказываетесь. Сергей разочарован, но понимает. Ваша жизнь становится еще более одинокой, вы теряете шанс на принадлежность.")
            ending_ostracized()
    else:
        slow_print("Ваше поведение вызвало подозрение у немцев, но и Молодая Гвардия не доверяет вам из-за вашей нерешительности. Вам трудно найти работу, вас постоянно обыскивают.")
        slow_print("Вы оказываетесь между двух огней, и никто вас не защищает. Вы одинокий изгой.")
        ending_ostracized()

def survival_collaboration_mild():
    slow_print("\n--- Сближение с врагом (Мягкое сотрудничество) ---")
    slow_print("Вы передаете немцам 'пустую' информацию, чтобы они не заподозрили вас. Но они начинают давать более серьезные задания.")
    characters["Обер-лейтенант Мюллер"].talk("Нам поступила информация, что семья Кузнецовых прячет советских солдат. Проверь это, {player_name}. Доложи о результатах.")
    display_status()

    options = [
        "1. Сообщить немцам неправду, подвергая себя риску разоблачения, но спасая семью.",
        "2. Сообщить правду, чтобы избежать наказания и остаться в безопасности.",
        "3. Попытаться предупредить семью, чтобы они скрылись (высокий риск)."
    ]
    choice = get_choice(options)

    if choice == 1:
        if simulate_skill_check("ingenuity", 8):
            slow_print("Вы успешно обманули немцев, предоставив ложный донос. Семья в безопасности, а вы еще не разоблачены.")
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 10)
            player_stats['loyalty_enemy'] = max(0, player_stats['loyalty_enemy'] - 10)
            ending_saved_self() # В конечном итоге приводит к этому
        else:
            slow_print("Немцы раскрыли ваш обман! Обер-лейтенант Мюллер в ярости. Вас жестоко наказывают и требуют полноценного сотрудничества.")
            player_stats['health'] -= 40
            if player_stats['health'] <= 0: game_over("Вы погибли под пытками за попытку обмануть немцев.")
            survival_captured_or_turned()
    elif choice == 2:
        slow_print("Вы сообщаете правду. Семью Кузнецовых арестовывают. На вашей совести теперь их жизни.")
        player_stats['loyalty_enemy'] = min(100, player_stats['loyalty_enemy'] + 15)
        player_stats['loyalty_resistance'] = max(0, player_stats['loyalty_resistance'] - 15)
        ending_collaborator() # Приспособленец
    elif choice == 3:
        if simulate_skill_check("stealth", 9):
            slow_print("Вы рискуете, но успеваете предупредить семью Кузнецовых. Они успевают скрыться, пока немцы обыскивают их дом.")
            player_stats['loyalty_resistance'] = min(100, player_stats['loyalty_resistance'] + 15)
            player_stats['loyalty_enemy'] = max(0, player_stats['loyalty_enemy'] - 15)
            player_stats['stealth'] = max(0, player_stats['stealth'] - 2)
            slow_print("Немцы злятся, но улик против вас нет. Вы чувствуете себя лучше, но теперь вы в опасности. Скрытность -2.")
            ending_saved_self()
        else:
            slow_print("Вас замечают, когда вы пытаетесь предупредить семью! Вас арестовывают как пособника сопротивления.")
            player_stats['health'] -= 30
            if player_stats['health'] <= 0: game_over("Вы погибли, пытаясь помочь семье.")
            survival_captured_or_turned()

def survival_collaboration_full():
    slow_print("\n--- Сближение с врагом (Полное сотрудничество) ---")
    slow_print("Вы полностью перешли на сторону оккупантов, активно выполняя их приказы. Вы предаете своих земляков, но получаете привилегии и безопасность.")
    characters["Обер-лейтенант Мюллер"].talk("Мы ценим твою лояльность, {player_name}. Теперь ты один из нас. Хочешь вступить в полицию или быть тайным осведомителем?")
    display_status()

    options = [
        "1. Вступить в полицию, получить форму и оружие (немецкий пистолет).",
        "2. Стать тайным осведомителем, продолжая жить среди местных, но донося на них."
    ]
    choice = get_choice(options)

    if choice == 1:
        slow_print("Вы надеваете немецкую форму полицая, получаете пистолет Walther P38 и патроны. Теперь вы – часть оккупационного аппарата, верный слуга Рейха.")
        add_item_to_inventory(items_data["Немецкая форма"])
        add_item_to_inventory(items_data["Пистолет (Walther P38)"])
        add_item_to_inventory(items_data["Патроны (10 шт.)"])
        game_events['has_pistol'] = True
        player_stats['loyalty_enemy'] = 100
        player_stats['loyalty_resistance'] = 0
        ending_collaborator_full()
    else:
        slow_print("Вы продолжаете действовать в тени, предавая своих. Ваши доносы приводят к арестам и казням. Вы – тень, несущая смерть в сердцах своих же людей.")
        player_stats['loyalty_enemy'] = 90
        player_stats['loyalty_resistance'] = 10
        ending_collaborator() # Приспособленец, но с высокой степенью предательства

def survival_captured_or_turned():
    slow_print("\n--- Эпилог: Выбор без Выбора ---")
    slow_print("Вас схватили. Тюремные застенки, холод и голод. Допросы, пытки... Ваше тело измучено, воля на грани.")
    if player_stats['health'] <= 0:
        game_over("Вас схватили и замучили до смерти. Ваша жизнь оборвана в застенках, безвестно.")

    slow_print(f"Ваше текущее здоровье: {player_stats['health']}/100.")
    slow_print("Выбор прост: смерть или сотрудничество с оккупантами.")

    options = [
        "1. Отказаться от сотрудничества, принять свою судьбу, сохранив честь (если хватит сил).",
        "2. Согласиться сотрудничать, чтобы выжить, любой ценой."
    ]
    choice = get_choice(options)

    if choice == 1:
        if player_stats['courage'] >= 50: # Если есть хоть какая-то смелость
            slow_print("Вы держитесь до конца. Ваша воля не сломлена, но жизнь оборвана в застенках. Вы погибаете, сохранив честь.")
            game_over("Вы погибли, сохранив честь. Ваше имя останется неизвестным, но ваша совесть чиста.")
        else:
            slow_print("Вы пытались отказаться, но страх и боль взяли верх. Вас сломили и заставили сотрудничать.")
            player_stats['loyalty_enemy'] = 100
            player_stats['loyalty_resistance'] = 0
            game_events['betrayal_degree'] = 3
            ending_collaborator_full()
    else:
        slow_print("Вы сломлены. Соглашаетесь работать на немцев. Ваше выживание будет стоить вам всего: чести, совести, души.")
        player_stats['loyalty_enemy'] = 100
        player_stats['loyalty_resistance'] = 0
        game_events['betrayal_degree'] = 3
        ending_collaborator_full()


# --- Варианты концовок ---

def heroic_ending():
    historical_note("Судьба Молодой Гвардии", "Реальные молодогвардейцы проявили исключительную храбрость и стойкость. Многие из них были схвачены, подвергнуты пыткам и казнены, но их подвиг вдохновил на борьбу и остался в истории как символ несокрушимого духа. Их имена – Ульяна Громова, Иван Земнухов, Сергей Тюленин, Любовь Шевцова, Олег Кошевой, Иван Туркенич и многие другие – навсегда останутся в памяти.")

    slow_print("\n" + "="*50)
    slow_print("КОНЦОВКА: ГЕРОИЧЕСКИЙ ФИНАЛ")
    if game_events['rescued_ulyana']:
        slow_print("Вы смогли спасти Ульяну Громову и, возможно, других товарищей. Ваша самоотверженность дала Молодой Гвардии еще один шанс продолжить борьбу.")
        slow_print("Вместе с теми, кто уцелел, вы продолжите сопротивление, вдохновляя своей стойкостью других. Ваша борьба продолжается!")
    elif game_events['acted_heroically_in_m4']:
        slow_print("Вы сражались до последнего, отвлекая огонь на себя или прикрывая отход товарищей. Ваша жертва спасла других.")
        slow_print("Ваше имя, возможно, не станет легендой для всех, но ваш подвиг будет жить в сердцах тех, кого вы спасли.")
    else:
        slow_print("Вы прошли путь Молодой Гвардии до конца, не свернув с пути борьбы. Многие пали, но их жертва не была напрасной.")
        slow_print("Ваш дух не сломлен, даже если вы не увидели победу. Вы стали символом несокрушимого духа народа.")

    slow_print("Пусть имена героев 'Молодой Гвардии' будут помнить вечно! Вы и ваши товарищи навсегда вписаны в историю.")
    slow_print("==================================================")
    slow_print("       ПОМНИМ ИХ ИМЕНА:")
    slow_print("     Ульяна Громова")
    slow_print("     Иван Земнухов")
    slow_print("     Сергей Тюленин")
    slow_print("     Любовь Шевцова")
    slow_print("     Олег Кошевой")
    slow_print("     Иван Туркенич")
    slow_print("     ...")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()

def survivor_ending():
    historical_note("Цена выживания", "В годы войны многие пытались выжить, сохраняя нейтралитет. Но часто это было невозможно. Каждый выбор имел последствия, и даже бездействие могло стоить очень дорого, оставляя глубокие шрамы на душе.")

    slow_print("\n" + "="*50)
    slow_print("КОНЦОВКА: ВЫЖИВШИЙ С ТЕНЬЮ НА ДУШЕ")
    slow_print("Вы выжили в том аду, но цена была высока. Многие ваши товарищи погибли, а вы не смогли (или не захотели) им помочь.")
    if player_stats['loyalty_resistance'] >= 50:
        slow_print("Вы не предали идеалов, но ваша роль оказалась пассивной. Память о павших будет преследовать вас всю жизнь, напоминая об упущенных шансах и нереализованном потенциале.")
    else:
        slow_print("Вы сохранили свою жизнь, но чувство вины и горечь потерь останутся с вами. Вы будете жить, помня о том, что могли бы сделать, но не сделали. Это груз, который нести тяжелее всего.")
    slow_print("Ваш путь был сложен, но вы не стали героем. Возможно, вы сможете рассказать их историю, чтобы их жертва не была забыта, искупив свою пассивность словом.")
    slow_print("==================================================")
    slow_print("           Даже в самые темные времена,")
    slow_print("          выбор есть всегда. И каждый выбор")
    slow_print("          имеет свои последствия, порой очень суровые.")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()

def lone_survivor_ending(): # Если вы прорвались, но не спасли Ульяну или других ключевых фигур
    historical_note("Партизанское движение", "Многие, кто избежал арестов или плена, уходили в леса и присоединялись к партизанским отрядам, продолжая борьбу против оккупантов. Они становились невидимыми мстителями.")

    slow_print("\n" + "="*50)
    slow_print("КОНЦОВКА: ОДИНОКИЙ БОРЕЦ")
    slow_print("Вы прорвались из города, оставив позади ужасы оккупации и гибель товарищей. Ваша судьба неизвестна, но вы не сдались.")
    slow_print("Вы ушли в леса, присоединились к партизанам или продолжили борьбу в одиночку. Этот путь был путем выживания, но и путем сохранения искры сопротивления.")
    slow_print("Вы не забыли тех, кто пал, и каждый ваш бой был местью за них. Ваша борьба продолжается в тени, за свободу Родины.")
    slow_print("==================================================")
    slow_print("          Надежда живет до тех пор, пока")
    slow_print("          есть те, кто готов бороться.")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()

def ending_ostracized():
    historical_note("Тяжесть выбора", "Даже в условиях оккупации, когда казалось, что нет выбора, люди сталкивались с моральными дилеммами. И те, кто выбирал путь бездействия или нейтралитета, часто становились изгоями для обеих сторон, не находя себе места нигде.")

    slow_print("\n" + "="*50)
    slow_print("КОНЦОВКА: ОТРЕКШИЙСЯ ИЛИ ИЗГОЙ")
    slow_print("Вы избегали активной борьбы, но и не стали слугой врага. Ваша нерешительность привела к тому, что вы оказались изгоем.")
    slow_print("Подполье не доверяло вам, немцы презирали. Вы выжили, но без поддержки и понимания, в одиночестве и постоянном страхе.")
    slow_print("Ваша жизнь после войны будет наполнена изоляцией, попытками оправдаться или забыть. Вы выбрали бездействие, и оно стало вашим проклятием.")
    slow_print("Вы дожили до старости, но воспоминания о несбывшихся подвигах и упущенных шансах преследуют вас. Вы живете, терзаемый сожалениями.")
    slow_print("==================================================")
    slow_print("          Цена бездействия порой выше,")
    slow_print("          чем цена борьбы.")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()

def ending_saved_self():
    historical_note("Двойная игра", "Некоторые люди, вынужденные сотрудничать с оккупантами, пытались играть двойную игру, чтобы помочь сопротивлению или минимизировать ущерб. Это был невероятно рискованный путь, полный моральных компромиссов.")

    slow_print("\n" + "="*50)
    slow_print("КОНЦОВКА: СПАСШИЙСЯ ЦЕНОЙ ДУШИ")
    slow_print("Вы смогли уклониться от прямого предательства, но и не участвовали в открытой борьбе. Ваша жизнь была чередой страха и попыток выжить любой ценой, избегая участия в зверствах врага, но и не помогая сопротивлению.")
    slow_print("Вы выжили, но ваше имя не войдет в историю ни как героя, ни как откровенного предателя. Вы просто были, человеком, который выбрал выживание любой ценой.")
    slow_print("Груз этих выборов будет лежать на вашей душе, возможно, до конца жизни. Вы избежали прямого возмездия, но цена была велика – потерянная чистота души.")
    slow_print("==================================================")
    slow_print("          Не каждый, кто выжил, был героем.")
    slow_print("          Но и не каждый погибший был побежден.")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()

def ending_collaborator(): # Объединение mild и full в зависимости от degree
    historical_note("Коллаборационизм", "Сотрудничество с оккупантами имело разные формы: от принудительного до добровольного по идеологическим или корыстным мотивам. Все коллаборационисты после войны столкнулись с осуждением и наказанием.")

    slow_print("\n" + "="*50)
    if game_events['betrayal_degree'] == 3: # Слуга врага
        slow_print("КОНЦОВКА: СЛУГА ВРАГА (Приспособленец)")
        slow_print("Вы полностью перешли на сторону оккупантов, активно участвуя в репрессиях и пособничестве. Ваша жизнь была спасена, но какой ценой?")
        if check_item_in_inventory(items_data["Немецкая форма"]):
            slow_print("В немецкой форме, с немецким пистолетом, вы вершили чужую волю, предавая своих соотечественников.")
        else:
            slow_print("Ваши доносы и информация стоили жизни многим невинным людям.")
        slow_print("После войны вы пытаетесь скрыть свое прошлое, но тени ваших деяний преследуют вас. Вы живете в страхе разоблачения, презираемые соседями, даже если они не знают всей правды.")
    else: # betrayal_degree == 2 (mild, но тоже предательство)
        slow_print("КОНЦОВКА: ПРИСПОСОБЛЕНЕЦ")
        slow_print("Вы выжили, сотрудничая с врагом, но не становясь открытым пособником. Вы пытались играть двойную игру, но она привела вас к предательству.")
        slow_print("После войны вы пытаетесь скрыть свое прошлое, но тени ваших деяний преследуют вас. Вы живете в страхе разоблачения, презираемые соседями, даже если они не знают всей правды.")

    slow_print("Ваш выбор принес вам выживание, но отнял честь и совесть. Этот путь ведет к вечному позору.")
    slow_print("==================================================")
    slow_print("          Самое страшное предательство -")
    slow_print("          это предательство самого себя.")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()

def ending_collaborator_full(): # Отдельная концовка для самых преданных врагу
    historical_note("Судьба предателей", "Коллаборационисты, активно сотрудничавшие с нацистами, после освобождения территорий подвергались суровым наказаниям, вплоть до смертной казни. Их имена покрыты позором, а память о них – проклятием.")

    slow_print("\n" + "="*50)
    slow_print("КОНЦОВКА: СЛУГА ВРАГА (Окончательное предательство)" )
    slow_print("Вы полностью перешли на сторону врага, добровольно став его инструментом. Вы предали свой народ и свою совесть.")
    slow_print("В немецкой форме, с оружием, вы активно участвовали в репрессиях, доносах и борьбе с сопротивлением. Ваша рука не дрогнула, когда приходилось уничтожать тех, кто боролся за свободу.")
    slow_print("После войны справедливость настигла вас. Ваше имя покрыто позором, и вы получили заслуженное наказание за свои преступления.")
    slow_print("Ваша жизнь закончилась в страхе и презрении, оставив после себя лишь горькое эхо предательства, которое будет помниться веками.")
    slow_print("==================================================")
    slow_print("          Предательство не прощается. Никогда.")
    slow_print("==================================================")
    time.sleep(5)
    sys.exit()


# --- Главный Цикл Игры ---
def start_game():
    slow_print("Запуск игры 'Эхо Подвига: Молодая Гвардия'...")
    prologue()
    # Если игра не закончилась через game_over(), это значит, что что-то пошло не так в логике сценария
    slow_print("\nСпасибо за игру! (Непредвиденное завершение, если вы не достигли одной из концовок.)")

if __name__ == "__main__":
    start_game()




