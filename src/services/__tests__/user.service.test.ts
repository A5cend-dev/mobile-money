jest.doMock("../../config/database", () => ({
  pool: {
    connect: jest.fn(),
    query: jest.fn(),
  },
}));

import { pool } from "../../config/database";
import { deactivateUserAccount } from "../userService";

describe("deactivateUserAccount", () => {
  let mockClient: any;

  beforeEach(() => {
    mockClient = {
      query: jest.fn(),
      release: jest.fn(),
    };

    (pool.connect as jest.Mock).mockResolvedValue(mockClient);
    (pool.query as jest.Mock).mockClear();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("succssful deactivation", () => {
    it("should scrub PII and deactivate user account", async () => {
      const userId = "user-123";

      // Mock pool.query returned value
      (pool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [{ id: userId, email: "test@example.com" }],
      });

      // Mock client.query for transaction queries
      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rowCount: 1 }) // users UPDATE
        // .mockResolvedValueOnce({ rowCount: 1 }) // user_profiles UPDATE
        // .mockResolvedValueOnce({ rowCount: 5 }) // sessions DELETE
        // .mockResolvedValueOnce({ rowCount: 2 }) // api_keys DELETE
        // .mockResolvedValueOnce({ rowCount: 10 }) // transactions UPDATE
        // .mockResolvedValueOnce({ rowCount: 1 }) // audit_log INSERT
        .mockResolvedValueOnce(undefined); // COMMIT

      await deactivateUserAccount(userId);

      // Debug: Log all calls
      console.log(
        "mockClient.query calls:",
        mockClient.query.mock.calls.length,
      );
      mockClient.query.mock.calls.forEach((call: any[], i: number) => {
        console.log(`Call ${i}:`, call[i]);
      });

      expect(pool.connect).toHaveBeenCalled();
      expect(mockClient.query).toHaveBeenCalledTimes(3);
      expect(mockClient.release).toHaveBeenCalled();
    });
  });
});
