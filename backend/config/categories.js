export const categories = [
  {
    id: 'indian_ecommerce',
    title: 'Local',
    priority: 1,
  },
  {
    id: 'quick_commerce',
    title: 'Quick',
    priority: 2,
  },
  {
    id: 'bulk',
    title: 'Bulk',
    priority: 3,
  },
  {
    id: 'international',
    title: 'Global',
    priority: 4,
  },
  {
    id: 'second_hand',
    title: 'Refurb',
    priority: 5,
  },
  {
    id: 'other',
    title: 'Other',
    priority: 6,
  },
];

export const categoryById = Object.fromEntries(
  categories.map((category) => [category.id, category]),
);
