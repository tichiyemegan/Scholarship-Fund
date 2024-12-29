import { describe, it, beforeEach, expect } from 'vitest';

// Mocking the Scholarship Fund contract for testing purposes
const mockScholarshipFund = {
  state: {
    totalFunds: 0 as number,
    donors: new Map<string, number>(),
    scholars: new Map<string, { amount: number; status: string }>(),
    owner: 'ST0000...', // Contract owner
  },
  donateFunds: (amount: number, sender: string) => {
    if (amount <= 0) return { error: 'Invalid amount' };
    mockScholarshipFund.state.totalFunds += amount;
    mockScholarshipFund.state.donors.set(sender, (mockScholarshipFund.state.donors.get(sender) || 0) + amount);
    return { value: amount };
  },
  awardScholarship: (scholar: string, amount: number, sender: string) => {
    if (sender !== mockScholarshipFund.state.owner) return { error: 'Owner only' };
    if (amount > mockScholarshipFund.state.totalFunds) return { error: 'Insufficient funds' };
    mockScholarshipFund.state.totalFunds -= amount;
    mockScholarshipFund.state.scholars.set(scholar, { amount, status: 'awarded' });
    return { value: amount };
  },
  getTotalFunds: () => {
    return mockScholarshipFund.state.totalFunds;
  },
  getDonorContribution: (donor: string) => {
    return mockScholarshipFund.state.donors.get(donor) || 0;
  },
  getScholarInfo: (scholar: string) => {
    return mockScholarshipFund.state.scholars.get(scholar) || null;
  },
};

describe('Scholarship Fund Contract', () => {
  let donor1: string, donor2: string, scholar1: string, owner: string;

  beforeEach(() => {
    // Initialize mock state and user principals
    donor1 = 'ST1234...';
    donor2 = 'ST5678...';
    scholar1 = 'ST9876...';
    owner = mockScholarshipFund.state.owner;

    mockScholarshipFund.state = {
      totalFunds: 0,
      donors: new Map(),
      scholars: new Map(),
      owner: 'ST0000...',
    };
  });

  it('should allow donations and update total funds', () => {
    const result = mockScholarshipFund.donateFunds(100, donor1);
    expect(result).toEqual({ value: 100 });
    expect(mockScholarshipFund.getTotalFunds()).toBe(100);
    expect(mockScholarshipFund.getDonorContribution(donor1)).toBe(100);
  });

  it('should retrieve donor contributions correctly', () => {
    mockScholarshipFund.donateFunds(200, donor1);
    mockScholarshipFund.donateFunds(150, donor2);
    expect(mockScholarshipFund.getDonorContribution(donor1)).toBe(200);
    expect(mockScholarshipFund.getDonorContribution(donor2)).toBe(150);
  });

  it('should award scholarships and update total funds', () => {
    mockScholarshipFund.donateFunds(300, donor1);
    const result = mockScholarshipFund.awardScholarship(scholar1, 200, owner);
    expect(result).toEqual({ value: 200 });
    expect(mockScholarshipFund.getTotalFunds()).toBe(100);
    const scholarInfo = mockScholarshipFund.getScholarInfo(scholar1);
    expect(scholarInfo).toEqual({ amount: 200, status: 'awarded' });
  });

  it('should prevent awarding scholarships if not the owner', () => {
    mockScholarshipFund.donateFunds(300, donor1);
    const result = mockScholarshipFund.awardScholarship(scholar1, 200, donor1);
    expect(result).toEqual({ error: 'Owner only' });
  });

  it('should prevent awarding scholarships if insufficient funds', () => {
    mockScholarshipFund.donateFunds(100, donor1);
    const result = mockScholarshipFund.awardScholarship(scholar1, 200, owner);
    expect(result).toEqual({ error: 'Insufficient funds' });
  });

  it('should retrieve scholar information correctly', () => {
    mockScholarshipFund.donateFunds(500, donor1);
    mockScholarshipFund.awardScholarship(scholar1, 300, owner);
    const scholarInfo = mockScholarshipFund.getScholarInfo(scholar1);
    expect(scholarInfo).toEqual({ amount: 300, status: 'awarded' });
  });

  it('should return null for non-existent scholar information', () => {
    const scholarInfo = mockScholarshipFund.getScholarInfo(scholar1);
    expect(scholarInfo).toBeNull();
  });
});
