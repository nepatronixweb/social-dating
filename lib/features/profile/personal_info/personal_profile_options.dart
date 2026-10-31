/// Selection catalogues for Personal Information. Values are stable ids stored
/// on the profile; labels are shown in the UI.
abstract final class PersonalProfileOptions {
  static const genders = [
    (id: 'male', label: 'Male'),
    (id: 'female', label: 'Female'),
    (id: 'non_binary', label: 'Non-binary'),
    (id: 'self_describe', label: 'Prefer to self-describe'),
  ];

  static const interestedIn = [
    (id: 'men', label: 'Men'),
    (id: 'women', label: 'Women'),
    (id: 'everyone', label: 'Everyone'),
  ];

  static const bodyTypes = [
    (id: 'slim', label: 'Slim'),
    (id: 'athletic', label: 'Athletic'),
    (id: 'average', label: 'Average'),
    (id: 'curvy', label: 'Curvy'),
    (id: 'plus_size', label: 'Plus size'),
  ];

  static const hairColors = [
    (id: 'black', label: 'Black'),
    (id: 'brown', label: 'Brown'),
    (id: 'blonde', label: 'Blonde'),
    (id: 'red', label: 'Red'),
    (id: 'grey', label: 'Grey'),
    (id: 'other', label: 'Other'),
  ];

  static const eyeColors = [
    (id: 'brown', label: 'Brown'),
    (id: 'black', label: 'Black'),
    (id: 'hazel', label: 'Hazel'),
    (id: 'blue', label: 'Blue'),
    (id: 'green', label: 'Green'),
    (id: 'other', label: 'Other'),
  ];

  static const fitnessLifestyles = [
    (id: 'very_active', label: 'Very active'),
    (id: 'active', label: 'Active'),
    (id: 'moderate', label: 'Moderate'),
    (id: 'light', label: 'Light'),
    (id: 'not_active', label: 'Not active'),
  ];

  static const drink = [
    (id: 'never', label: 'Never'),
    (id: 'occasionally', label: 'Occasionally'),
    (id: 'socially', label: 'Socially'),
    (id: 'frequently', label: 'Frequently'),
  ];

  static const smoke = [
    (id: 'never', label: 'Never'),
    (id: 'occasionally', label: 'Occasionally'),
    (id: 'regularly', label: 'Regularly'),
  ];

  static const exercise = [
    (id: 'daily', label: 'Daily'),
    (id: 'sometimes', label: 'Sometimes'),
    (id: 'rarely', label: 'Rarely'),
  ];

  static const food = [
    (id: 'vegetarian', label: 'Vegetarian'),
    (id: 'non_vegetarian', label: 'Non-vegetarian'),
    (id: 'vegan', label: 'Vegan'),
    (id: 'other', label: 'Other'),
  ];

  static const pets = [
    (id: 'love_pets', label: 'Love pets'),
    (id: 'have_pets', label: 'Have pets'),
    (id: 'not_interested', label: 'Not interested'),
  ];

  static const sleep = [
    (id: 'early_bird', label: 'Early bird'),
    (id: 'night_owl', label: 'Night owl'),
    (id: 'flexible', label: 'Flexible'),
  ];

  static const social = [
    (id: 'introvert', label: 'Introvert'),
    (id: 'extrovert', label: 'Extrovert'),
    (id: 'ambivert', label: 'Ambivert'),
  ];

  static const education = [
    (id: 'high_school', label: 'High school'),
    (id: 'diploma', label: 'Diploma'),
    (id: 'bachelors', label: "Bachelor's"),
    (id: 'masters', label: "Master's"),
    (id: 'doctorate', label: 'Doctorate'),
    (id: 'other', label: 'Other'),
  ];

  static const professions = [
    (id: 'student', label: 'Student'),
    (id: 'engineer', label: 'Engineer'),
    (id: 'doctor', label: 'Doctor'),
    (id: 'teacher', label: 'Teacher'),
    (id: 'business', label: 'Business'),
    (id: 'creative', label: 'Creative'),
    (id: 'service', label: 'Service'),
    (id: 'other', label: 'Other'),
  ];

  static const languages = [
    (id: 'nepali', label: 'Nepali'),
    (id: 'english', label: 'English'),
    (id: 'hindi', label: 'Hindi'),
    (id: 'maithili', label: 'Maithili'),
    (id: 'newari', label: 'Newari'),
    (id: 'bhojpuri', label: 'Bhojpuri'),
    (id: 'other', label: 'Other'),
  ];

  static const income = [
    (id: 'prefer_not', label: 'Prefer not to say'),
    (id: 'under_25k', label: 'Under NPR 25,000'),
    (id: '25_50k', label: 'NPR 25,000–50,000'),
    (id: '50_100k', label: 'NPR 50,000–100,000'),
    (id: '100k_plus', label: 'NPR 100,000+'),
  ];

  static const lookingFor = [
    (id: 'relationship', label: 'Relationship'),
    (id: 'marriage', label: 'Marriage'),
    (id: 'casual', label: 'Casual dating'),
    (id: 'friendship', label: 'Friendship'),
  ];

  static const distancesKm = [5, 10, 25, 50, 100];

  static const preferredLocations = [
    (id: 'city', label: 'City'),
    (id: 'nearby', label: 'Nearby'),
    (id: 'anywhere', label: 'Anywhere'),
  ];

  static const children = [
    (id: 'want', label: 'Want children'),
    (id: 'dont_want', label: "Don't want"),
    (id: 'not_sure', label: 'Not sure'),
    (id: 'have', label: 'Have children'),
  ];

  static const relationshipStatus = [
    (id: 'single', label: 'Single'),
    (id: 'divorced', label: 'Divorced'),
    (id: 'widowed', label: 'Widowed'),
  ];

  static const meetFrequency = [
    (id: 'frequently', label: 'Frequently'),
    (id: 'occasionally', label: 'Occasionally'),
    (id: 'flexible', label: 'Flexible'),
  ];

  static const interests = [
    'Traveling',
    'Music',
    'Movies',
    'Technology',
    'Gaming',
    'Sports',
    'Cooking',
    'Reading',
    'Photography',
    'Adventure',
    'Business',
    'Entrepreneurship',
    'Fitness',
    'Nature',
    'Art',
    'Dancing',
  ];

  static const minInterests = 3;

  static const personality = social;

  static const perfectWeekend = [
    (id: 'traveling', label: 'Traveling'),
    (id: 'staying_home', label: 'Staying home'),
    (id: 'party', label: 'Party'),
    (id: 'adventure', label: 'Adventure'),
  ];

  static const loveLanguage = [
    (id: 'quality_time', label: 'Quality time'),
    (id: 'gifts', label: 'Gifts'),
    (id: 'words', label: 'Words'),
    (id: 'acts', label: 'Acts of service'),
    (id: 'touch', label: 'Physical touch'),
  ];

  static const communication = [
    (id: 'calls', label: 'Calls'),
    (id: 'texts', label: 'Texts'),
    (id: 'video', label: 'Video calls'),
  ];

  static const firstDate = [
    (id: 'coffee', label: 'Coffee'),
    (id: 'dinner', label: 'Dinner'),
    (id: 'movie', label: 'Movie'),
    (id: 'adventure', label: 'Adventure'),
  ];

  static const promptChoices = [
    (id: 'ideal_sunday', label: 'My ideal Sunday looks like...'),
    (id: 'make_me_smile', label: 'The quickest way to make me smile is...'),
    (id: 'cannot_live_without', label: 'One thing I cannot live without...'),
    (id: 'biggest_dream', label: 'My biggest dream is...'),
    (id: 'looking_for_someone', label: 'I am looking for someone who...'),
    (id: 'fun_fact', label: 'A fun fact about me...'),
  ];

  static const promptSlots = 3;

  static const nepalCities = [
    'Kathmandu',
    'Lalitpur',
    'Bhaktapur',
    'Pokhara',
    'Biratnagar',
    'Birgunj',
    'Dharan',
    'Butwal',
    'Nepalgunj',
    'Hetauda',
    'Janakpur',
    'Chitwan',
  ];

  static String? labelOf(
    List<({String id, String label})> options,
    String? id,
  ) {
    if (id == null || id.isEmpty) return null;
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return id;
  }
}
