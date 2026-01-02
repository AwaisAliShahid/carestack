class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  # Roles
  ROLES = %w[admin manager member].freeze

  # Relationships
  belongs_to :account, optional: true

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }

  # Scopes
  scope :admins, -> { where(role: "admin") }
  scope :managers, -> { where(role: "manager") }
  scope :members, -> { where(role: "member") }
  scope :for_account, ->(account) { where(account: account) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def admin?
    role == "admin"
  end

  def manager?
    role == "manager"
  end

  def member?
    role == "member"
  end

  def can_manage_account?
    admin? || manager?
  end
end
