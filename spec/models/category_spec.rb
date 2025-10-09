# spec/models/category_spec.rb
require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:user) { create(:user) }
  let(:valid_attributes) do
    {
      user: user,
      name: 'Programming',
      color: '#FF5733'
    }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    # Updated to match our safer implementation
    it { should have_many(:time_entries).dependent(:restrict_with_error) }

    it 'supports parent-child relationships' do
      parent = create(:category, user: user, name: 'Work')
      child = create(:category, user: user, parent_category: parent, name: 'Meetings')
      expect(child.parent_category).to eq(parent)
      expect(parent.subcategories).to include(child)
    end

    it 'allows multiple levels of nesting' do
      grandparent = create(:category, user: user, name: 'Projects')
      parent = create(:category, user: user, parent_category: grandparent, name: 'Website')
      child = create(:category, user: user, parent_category: parent, name: 'Frontend')
      expect(child.root_category).to eq(grandparent)
      expect(child.depth_level).to eq(2)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      category = Category.new(valid_attributes)
      expect(category).to be_valid
    end

    it 'requires a user' do
      category = Category.new(valid_attributes.except(:user))
      expect(category).not_to be_valid
      expect(category.errors[:user]).to include('must exist')
    end

    it 'requires a name' do
      category = Category.new(valid_attributes.except(:name))
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it 'validates name length' do
      category = Category.new(valid_attributes.merge(name: 'a' * 101))
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include('is too long (maximum is 100 characters)')
    end

    it 'requires unique names per user' do
      create(:category, user: user, name: 'Exercise')
      duplicate = build(:category, user: user, name: 'Exercise')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'allows same name for different users' do
      create(:category, user: user, name: 'Reading')
      other_user = create(:user)
      category = build(:category, user: other_user, name: 'Reading')
      expect(category).to be_valid
    end

    it 'validates color format when provided' do
      category = Category.new(valid_attributes.merge(color: 'not-a-color'))
      expect(category).not_to be_valid
      expect(category.errors[:color]).to include('must be a valid hex color (e.g., #FF5733)')
    end

    it 'allows nil color' do
      category = Category.new(valid_attributes.merge(color: nil))
      expect(category).to be_valid
    end

    it 'prevents circular parent references' do
      category = create(:category, user: user)
      category.parent_category_id = category.id
      expect(category).not_to be_valid
      expect(category.errors[:parent_category_id]).to include("can't be a circular reference")
    end
  end

  describe 'scopes' do
    before do
      # Use unique names for each test to avoid conflicts
      @work = create(:category, user: user, name: 'Work Scope Test')
      @personal = create(:category, user: user, name: 'Personal Scope Test')
      @work_meetings = create(:category, user: user, parent_category: @work, name: 'Meetings')
    end

    it 'returns only top-level categories with .top_level scope' do
      top_level = Category.top_level
      expect(top_level).to include(@work, @personal)
      expect(top_level).not_to include(@work_meetings)
    end

    it 'orders categories alphabetically with .alphabetical scope' do
      categories = user.categories.alphabetical
      expect(categories.map(&:name)).to eq(categories.map(&:name).sort)
    end
  end

  describe 'instance methods' do
    describe '#full_name' do
      it 'returns just the name for top-level categories' do
        category = create(:category, user: user, name: 'Work Method Test')
        expect(category.full_name).to eq('Work Method Test')
      end

      it 'returns parent > child format for subcategories' do
        parent = create(:category, user: user, name: 'Parent Test')
        child = create(:category, user: user, parent_category: parent, name: 'Child Test')
        expect(child.full_name).to eq('Parent Test > Child Test')
      end

      it 'handles multiple levels of nesting' do
        grandparent = create(:category, user: user, name: 'Level 1')
        parent = create(:category, user: user, parent_category: grandparent, name: 'Level 2')
        child = create(:category, user: user, parent_category: parent, name: 'Level 3')
        expect(child.full_name).to eq('Level 1 > Level 2 > Level 3')
      end
    end

    describe '#total_time_for_period' do
      let(:category) { create(:category, user: user, name: 'Time Test Category') }

      it 'calculates total minutes for a date range' do
        # Create time entries with different hours to avoid conflicts
        create(:time_entry, user: user, category: category,
               date: Date.today, hour: 9, duration_minutes: 30)
        create(:time_entry, user: user, category: category,
               date: Date.today, hour: 10, duration_minutes: 45)

        total = category.total_time_for_period(Date.today, Date.today)
        expect(total).to eq(75)
      end

      it 'includes time from subcategories when specified' do
        child = create(:category, user: user, parent_category: category, name: 'Sub Time Test')

        # Use different hours for each time entry
        create(:time_entry, user: user, category: category,
               date: Date.today, hour: 8, duration_minutes: 30)
        create(:time_entry, user: user, category: child,
               date: Date.today, hour: 9, duration_minutes: 20)

        total_without_children = category.total_time_for_period(Date.today, Date.today)
        expect(total_without_children).to eq(30)

        total_with_children = category.total_time_for_period(Date.today, Date.today, include_children: true)
        expect(total_with_children).to eq(50)
      end
    end

    describe '#descendant_ids' do
      it 'returns all descendant category IDs' do
        parent = create(:category, user: user, name: 'Parent Descendant Test')
        child1 = create(:category, user: user, parent_category: parent, name: 'Child 1')
        child2 = create(:category, user: user, parent_category: parent, name: 'Child 2')
        grandchild = create(:category, user: user, parent_category: child1, name: 'Grandchild')

        descendants = parent.descendant_ids
        expect(descendants).to contain_exactly(child1.id, child2.id, grandchild.id)
      end
    end
  end

  describe 'callbacks' do
    it 'assigns a default color if none provided' do
      category = create(:category, :without_color, user: user)
      expect(category.color).to match(/^#[0-9a-fA-F]{6}$/)
    end

    it 'prevents deletion if time entries exist' do
      category = create(:category, user: user)
      create(:time_entry, user: user, category: category, hour: 12)

      expect { category.destroy }.not_to change(Category, :count)
      expect(category.errors[:base]).to include("Cannot delete record because dependent time entries exist")
    end
  end
end