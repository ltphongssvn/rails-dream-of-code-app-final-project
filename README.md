# Rails Dream of Code - Time Tracker

A full-featured time tracking application built with Ruby on Rails that helps users log hourly activities, set productivity goals, and analyze time usage patterns.

## 🎯 Features

### Time Management
- **Hourly Time Logging**: Track activities for each hour with categories and notes
- **Daily Timeline View**: Visualize your entire day at a glance
- **Category Management**: Organize activities with custom categories and colors
- **Quick Entry**: Add time entries with a user-friendly form interface

### Goal Tracking
- **Flexible Goals**: Set daily, weekly, or monthly productivity targets
- **Streak Tracking**: Monitor consecutive days of goal achievement
- **Completion Rates**: View percentage-based progress metrics
- **Day-Specific Goals**: Configure goals for specific days of the week

### Analytics & Reporting
- **Dashboard**: See today's progress, active goals, and weekly totals
- **Time Breakdown**: Analyze time spent per category
- **Historical Data**: Compare current patterns with past activity
- **Weekly Reports**: Get comprehensive weekly summaries

## 🚀 Live Demo

Visit the app at: http://localhost:3001 (when running locally)

## 📋 Prerequisites

- Docker Desktop (for containerized deployment)
- Git
- Railway CLI (optional, for cloud database)

## 🛠️ Installation & Setup

### 1. Clone Repository
```bash
git clone https://github.com/ltphongssvn/rails-dream-of-code-app-final-project.git
cd rails-dream-of-code-app-final-project
```

### 2. Configure Environment
```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your credentials:
# - RAILS_MASTER_KEY (from config/master.key)
# - SECRET_KEY_BASE (generate with: openssl rand -hex 64)
# - DATABASE_URL (Railway PostgreSQL connection string)
```

### 3. Start Application
```bash
# Build and start containers
docker compose up -d

# View logs
docker compose logs web -f
```

### 4. Access Application
Open browser to: http://localhost:3001

## 🗄️ Database Configuration

### Using Railway PostgreSQL (Production)
1. Install Railway CLI: `npm install -g @railway/cli`
2. Login: `railway login`
3. Create project: `railway init`
4. Add PostgreSQL: `railway add` → Select Database → PostgreSQL
5. Get credentials: `railway variables`
6. Update `.env` with `DATABASE_URL`

### Using Local PostgreSQL (Development)
Update `docker-compose.yml` to include local PostgreSQL service (see git history for configuration).

## 🧪 Testing

```bash
# Run full test suite
docker compose exec web bundle exec rspec

# Run specific test file
docker compose exec web bundle exec rspec spec/models/goal_spec.rb

# Test coverage: 299 examples, 0 failures, 5 pending
```

## 📁 Project Structure

```
app/
├── controllers/     # Request handlers
├── models/          # Data models with validations
├── views/           # ERB templates with Tailwind CSS
├── mailers/         # Email functionality
└── assets/          # Stylesheets and compiled assets

config/
├── database.yml     # Database configuration
├── routes.rb        # URL routing
└── environments/    # Environment-specific settings

spec/
├── models/          # Model tests
├── requests/        # Request specs
└── factories/       # Test data factories

docker-compose.yml   # Container orchestration
Dockerfile          # Production image definition
```

## 🎨 Design & Styling

- **Framework**: Tailwind CSS 4.x
- **Components**: Responsive cards, forms, and navigation
- **Color Scheme**: Blue/indigo primary with category-specific colors
- **Icons**: Emoji-based visual indicators

## 🔒 Security Features

- Password reset via email with signed tokens
- Secure session management
- CSRF protection
- Environment-based secret management
- SQL injection prevention via ActiveRecord

## 📊 Key Models & Relationships

```ruby
User
├── has_many :time_entries
├── has_many :goals
└── has_many :categories

TimeEntry
├── belongs_to :user
└── belongs_to :category

Goal
├── belongs_to :user
├── belongs_to :category (optional)
└── has_many :goal_completions

Category
├── belongs_to :user
├── belongs_to :parent (optional)
└── has_many :subcategories
```

## 🚢 Deployment

### Docker Production
```bash
docker compose build
docker compose up -d
```

### Railway Deployment
```bash
# Link to Railway project
railway link

# Deploy
railway up
```

## 🧑‍💻 Development

### Local Development
```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start server
rails server
```

### Running Tests
```bash
bundle exec rspec
```

## 📝 API Endpoints

- `GET /` - Home page (authenticated/unauthenticated views)
- `GET /time_entries` - Daily time entry grid
- `GET /goals` - Goal management
- `GET /categories` - Category organization
- `GET /dashboard` - Analytics dashboard
- `GET /reports/weekly` - Weekly summary

## 🤝 Contributing

This is a final project for Rails course. Contributions are welcome via pull requests.

## 👤 Author

**Thanh Phong Le**
- GitHub: [@ltphongssvn](https://github.com/ltphongssvn)

## 📜 License

This project is part of Rails course final assignment.

## 🏆 Project Status

✅ **Production Ready**
- Complete CRUD functionality
- Full test coverage (299 passing specs)
- Tailwind CSS styling
- Railway PostgreSQL integration
- Docker containerization

## 📸 Screenshots

### Dashboard
View daily progress, active goals, and quick actions.

### Time Entries
Hourly grid interface for tracking activities throughout the day.

### Goals
Set and monitor productivity targets with streak tracking.

### Categories
Organize activities with custom categories and subcategories.

## 🔧 Configuration

### Environment Variables
```bash
RAILS_ENV=production
RAILS_MASTER_KEY=<from config/master.key>
SECRET_KEY_BASE=<generated secret>
DATABASE_URL=postgresql://user:pass@host:port/dbname
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

## 📚 Documentation

For detailed documentation on specific features:
- See `ARCHITECTURE_REVIEW.md` for system architecture
- See `TEST_SUMMARY.md` for testing strategy

## 🐛 Known Issues

- None currently reported

## 🗓️ Roadmap

- [ ] Mobile responsive improvements
- [ ] Export data to CSV/PDF
- [ ] Team collaboration features
- [ ] API for third-party integrations

---

**Built with ❤️ using Ruby on Rails**
